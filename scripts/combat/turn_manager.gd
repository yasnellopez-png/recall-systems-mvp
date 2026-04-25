# TurnManager: el director de orquesta del combate.
#
# Qué hace:
#   1. Recibe dos listas de Combatants: party (aliados) y enemies.
#   2. Al empezar una ronda, calcula la INICIATIVA de cada combatiente vivo
#      con la fórmula:  iniciativa = SPD + randi_range(0, SPD / 4)
#      y construye la cola de turnos (de mayor a menor iniciativa).
#   3. Emite "turn_started(combatant)" cuando le toca a alguien.
#   4. Espera a que algún otro sistema (UI del jugador o IA) llame a
#      submit_action(action, target). Así el TurnManager NO SABE si el
#      turno actual es humano o IA; su única preocupación es el flujo.
#   5. Resuelve la acción, emite "damage_dealt", avanza al siguiente turno.
#   6. Cuando un equipo entero muere, emite "combat_ended(victory)".
#
# Este diseño es el patrón State Machine + Observer:
#   - El estado vive en el TurnManager (current_combatant, turn_order).
#   - La comunicación hacia fuera es solo por señales.
#   - En Python sería similar a una clase con métodos pequeños más
#     callbacks registrados por listeners externos.

class_name TurnManager
extends Node


# -------------------------------------------------------------------
# SEÑALES PÚBLICAS
# -------------------------------------------------------------------

# Se emite una vez al empezar el combate, con las listas iniciales.
# La UI la usa para pintar retratos y barras de HP.
signal combat_started(party: Array, enemies: Array)

# Se emite al inicio de cada ronda con el orden calculado.
# "order" es una copia (duplicate) para que suscriptores no la muten.
signal round_started(round_number: int, order: Array)

# Se emite cuando empieza el turno de un combatiente concreto.
# Si es del jugador, la UI habilita el panel de acciones.
# Si es enemigo, la IA elige y llama submit_action().
signal turn_started(combatant: Combatant)

# Se emite justo después de resolver la acción del turno.
# Útil para animaciones de "ya actuó".
signal turn_ended(combatant: Combatant)

# Se emite cuando un Atacar hace daño. Incluye la cantidad FINAL aplicada.
signal damage_dealt(attacker: Combatant, target: Combatant, amount: int)

# Se emite una sola vez, al final del combate.
# victory=true si sobrevivió al menos un aliado; false si todos cayeron.
signal combat_ended(victory: bool)


# -------------------------------------------------------------------
# ROSTER Y ESTADO
# -------------------------------------------------------------------

# Las listas de combatientes se guardan SIN tipar estrictamente, porque
# Array.filter() devuelve Array genérico y eso crearía peleas de tipos.
# El contenido sigue siendo Combatant en todos los casos.
var party: Array = []
var enemies: Array = []
var all_combatants: Array = []

# Número de ronda actual (1-based para que los logs sean amigables).
var round_number: int = 0

# Cola de combatientes pendientes de actuar en la ronda actual.
# Se vacía a medida que cada uno consume su turno.
var turn_order: Array = []

# Combatiente que está actuando AHORA (o null si el combate no empezó /
# terminó).
var current_combatant: Combatant = null

# Bandera para ignorar llamadas tardías después del fin del combate.
var is_active: bool = false


# -------------------------------------------------------------------
# API PÚBLICA — entrada principal
# -------------------------------------------------------------------

# Arranca un combate nuevo con las listas indicadas.
# Debe llamarse UNA vez, después de que los Combatant ya tengan setup().
func start_combat(p_party: Array, p_enemies: Array) -> void:
	party = p_party
	enemies = p_enemies

	# Unimos las dos listas en all_combatants. append_array() es como
	# "lista.extend(otra_lista)" en Python.
	all_combatants = []
	all_combatants.append_array(party)
	all_combatants.append_array(enemies)

	# Nos suscribimos a la señal "died" de cada combatiente. Así, cuando
	# uno muera, el TurnManager podrá revisar si el combate acabó.
	# La guardia "is_connected" evita conectar dos veces si start_combat()
	# se llama de nuevo (defensivo; no debería pasar).
	for c in all_combatants:
		if not c.died.is_connected(_on_combatant_died):
			c.died.connect(_on_combatant_died)

	round_number = 0
	is_active = true

	print("[TurnManager] === Combate iniciado: ", party.size(), " aliados vs ", enemies.size(), " enemigos ===")
	combat_started.emit(party, enemies)
	_start_round()


# API que usan el panel de acciones del jugador y la IA enemiga.
# "action" es el qué (Atacar / Defender). "target" es a quién (puede ser
# null si la acción no necesita objetivo, como Defender).
func submit_action(action: BattleAction, target: Combatant = null) -> void:
	# Guardia: ignoramos llamadas si el combate ya terminó o no hay turno activo.
	if not is_active or current_combatant == null:
		return

	var actor: Combatant = current_combatant

	# match es como el match/case de Python 3.10+.
	match action.kind:
		BattleAction.Kind.ATTACK:
			_resolve_attack(actor, target, action.damage_type)
		BattleAction.Kind.DEFEND:
			actor.start_defending()

	turn_ended.emit(actor)

	# ¿Se acabó el combate con esta acción? Si sí, paramos aquí.
	if _check_combat_end():
		return

	# Si no, pasamos al siguiente turno.
	_next_turn()


# -------------------------------------------------------------------
# ACCESORES DE CONVENIENCIA
# -------------------------------------------------------------------

# ¿El turno actual es de un aliado? La UI lo consulta para decidir si
# habilita el panel de acciones del jugador.
func is_current_player_side() -> bool:
	return current_combatant != null and current_combatant.is_player_side


# Devuelve la lista de aliados vivos. Útil para la IA enemiga.
func get_alive_party() -> Array:
	# filter() con lambda es lo mismo que [c for c in party if c.is_alive()]
	# en Python (una list comprehension con condición).
	return party.filter(func(c): return c.is_alive())


# Devuelve la lista de enemigos vivos. Útil para la UI del jugador.
func get_alive_enemies() -> Array:
	return enemies.filter(func(c): return c.is_alive())


# -------------------------------------------------------------------
# LÓGICA INTERNA — flujo de rondas y turnos
# -------------------------------------------------------------------

# Arranca una nueva ronda: recalcula iniciativa y llena turn_order.
# Se llama al inicio del combate y después de que todos actúen una vez.
func _start_round() -> void:
	if not is_active:
		return

	round_number += 1

	# Solo entran los vivos. Si alguien murió en la ronda anterior, no
	# recibe turno en la siguiente.
	var alive: Array = all_combatants.filter(func(c): return c.is_alive())

	# Construimos una lista de dicts {c, init} para poder ordenar por init.
	# En Python sería [{"c": c, "init": ...} for c in alive].
	var with_init: Array = []
	for c in alive:
		var spd: int = c.get_spd()
		# Evitamos división entera por cero si SPD < 4.
		# randi_range(0, N) devuelve un entero en [0, N] inclusive.
		var bonus_max: int = spd / 4
		var init_bonus: int = randi_range(0, bonus_max) if bonus_max > 0 else 0
		var init_total: int = spd + init_bonus
		# append() agrega al final de la lista, igual que en Python.
		with_init.append({"c": c, "init": init_total})

	# sort_custom() acepta una función de comparación que devuelve true
	# si "a debe ir antes que b". Ordenamos DESCENDENTE por iniciativa.
	with_init.sort_custom(func(a, b): return a["init"] > b["init"])

	# Reconstruimos turn_order solo con las referencias al Combatant.
	turn_order = []
	for entry in with_init:
		turn_order.append(entry["c"])

	# Log legible para ver el orden de esta ronda.
	print("[TurnManager] --- Ronda ", round_number, " ---")
	for entry in with_init:
		print("    ", entry["c"].get_display_name(), "  SPD=", entry["c"].get_spd(), "  iniciativa=", entry["init"])

	# Emitimos una copia (duplicate) para que suscriptores no puedan
	# mutar nuestra cola interna por error.
	round_started.emit(round_number, turn_order.duplicate())

	# Arrancamos el primer turno de la ronda.
	_next_turn()


# Saca al siguiente combatiente vivo de la cola y empieza su turno.
# Si la cola está vacía, arranca una nueva ronda.
func _next_turn() -> void:
	if not is_active:
		return

	# Saltamos cadáveres que pudieran haber muerto a media ronda.
	# "pop_front()" es como "lista.pop(0)" en Python.
	while not turn_order.is_empty() and not turn_order[0].is_alive():
		turn_order.pop_front()

	# Si la cola se vació, esta ronda terminó: empezamos otra.
	if turn_order.is_empty():
		# Chequeo preventivo por si alguien murió justo al final.
		if _check_combat_end():
			return
		_start_round()
		return

	# Sacamos el siguiente y lo convertimos en el combatiente activo.
	current_combatant = turn_order.pop_front()

	# Regla de Defender: dura "hasta el próximo turno del defensor".
	# Ahora mismo es el turno del defensor, así que bajamos la guardia.
	# Si no estaba defendiendo, end_defending() es un no-op seguro.
	current_combatant.end_defending()

	print("[TurnManager] Turno de ", current_combatant.get_display_name(), "  (HP ", current_combatant.hp_actual, "/", current_combatant.stats.max_hp, ")")
	turn_started.emit(current_combatant)


# Aplica un ataque básico: daño = max(1, atacante.ATK - objetivo.DEF).
# El objetivo se encarga internamente de aplicar su bandera de defensa.
func _resolve_attack(attacker: Combatant, target: Combatant, damage_type: String) -> void:
	# Objetivo inválido: ningún target o ya muerto. Se salta silencioso.
	if target == null or not target.is_alive():
		print("[TurnManager] ", attacker.get_display_name(), " ataca pero el objetivo no es válido.")
		return

	# Fórmula: daño bruto = max(1, ATK - DEF). El max(1,...) garantiza
	# que siempre haya al menos 1 punto antes de pasar a take_damage().
	var raw: int = max(1, attacker.get_atk() - target.get_def())

	# take_damage devuelve el daño FINAL (ya con defender aplicado).
	var applied: int = target.take_damage(raw, damage_type)

	print("[TurnManager] ", attacker.get_display_name(), " ataca a ", target.get_display_name(), " por ", applied, " (", damage_type, ").")
	damage_dealt.emit(attacker, target, applied)


# Revisa si el combate acabó. Si sí, lo marca y emite combat_ended.
# Devuelve true si terminó (el caller debe parar su flujo).
func _check_combat_end() -> bool:
	# "any alive" en cada bando = queda al menos uno vivo.
	var party_alive: bool = _any_alive(party)
	var enemies_alive: bool = _any_alive(enemies)

	if party_alive and enemies_alive:
		return false

	# Uno de los bandos cayó. Ganó quien haya sobrevivido.
	is_active = false
	current_combatant = null
	var victory: bool = party_alive

	# El ternario "a if cond else b" existe igual en Python.
	var resultado: String = "VICTORIA" if victory else "DERROTA"
	print("[TurnManager] === Combate terminado: ", resultado, " ===")
	combat_ended.emit(victory)
	return true


# Helper: ¿hay al menos un combatiente vivo en esta lista?
func _any_alive(group: Array) -> bool:
	# Un "for + return True" es la traducción directa del any() de Python.
	for c in group:
		if c.is_alive():
			return true
	return false


# -------------------------------------------------------------------
# CALLBACKS DE SEÑALES
# -------------------------------------------------------------------

# Se dispara automáticamente cuando cualquier Combatant emite "died".
# No hace falta actuar aquí; _check_combat_end() se llama tras cada acción.
# Lo dejamos solo por si más adelante queremos lógica extra (ej. pop-up
# "enemigo derrotado", recolocar barras, etc.).
func _on_combatant_died(_combatant: Combatant) -> void:
	pass
