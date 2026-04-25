# Combatant: nodo que representa a un participante en combate (aliado o enemigo).
#
# Responsabilidad única: llevar el estado vivo del participante durante una
# batalla (HP actual, si está defendiendo, etc.) y emitir señales cuando algo
# cambia. No dibuja nada por sí mismo; la parte visual vive en combat.tscn
# y se actualiza escuchando las señales de este nodo.
#
# Paralelo mental:
#   - "CharacterStats" es la plantilla inmutable (como una @dataclass en Python).
#   - "Combatant" es la instancia viva que nace de esa plantilla y se va
#     modificando durante el combate (como el objeto que creas a partir del
#     dataclass y al que le modificas sus atributos).
#
# Se comunica SOLO por señales; TurnManager y la UI se suscriben.
# Este desacoplamiento se parece al patrón "observer" de Python
# (ej. tkinter bind, signals de PyQt).

# "class_name" registra la clase globalmente; desde otros scripts puedes
# escribir "var c: Combatant = ..." sin necesidad de preload.
class_name Combatant
extends Node2D


# -------------------------------------------------------------------
# SEÑALES PÚBLICAS
# -------------------------------------------------------------------

# Se emite cada vez que cambia el HP actual (daño, curación, o setup inicial).
# La UI de la barra de vida escuchará esta señal para repintarse.
signal hp_changed(current_hp: int, max_hp: int)

# Se emite una sola vez, cuando el HP llega a 0.
# El TurnManager la escucha para detectar fin de combate (equipo muerto).
signal died(combatant: Combatant)

# Se emite justo después de aplicar daño; útil para popups de "-12" en pantalla.
# Lleva la cantidad FINAL (ya con defensa aplicada).
signal damage_taken(combatant: Combatant, amount: int)


# -------------------------------------------------------------------
# CONFIGURACIÓN (editable desde el inspector)
# -------------------------------------------------------------------

# Plantilla de stats. Se puede asignar un .tres desde el inspector O
# pasarla por código con setup(stats). Si se asigna en el inspector,
# _ready() la aplica automáticamente.
@export var stats: CharacterStats

# true = está en el equipo del jugador (party), false = es enemigo.
# Lo usan el TurnManager (para detectar equipos muertos) y la IA enemiga
# (para elegir a quién atacar).
@export var is_player_side: bool = true


# -------------------------------------------------------------------
# ESTADO VIVO DURANTE EL COMBATE
# -------------------------------------------------------------------

# HP actual. Arranca en 0; setup() lo iguala a stats.max_hp.
var hp_actual: int = 0

# Éter actual. Reservado para el sistema de hechizos (Paso 7+).
# Por ahora no se consume ni regenera.
var eter_actual: int = 0

# Bandera de defensa: si está en true, el próximo daño recibido se reduce
# al 50%. TurnManager la pone en true cuando el jugador elige "Defender"
# y la vuelve a poner en false cuando arranca el siguiente turno de
# este mismo combatiente.
var is_defending: bool = false

# Lista de efectos de estado activos (veneno, miedo, silencio, etc.).
# Reservado para el Paso 6+. Por ahora no se usa; solo vive aquí para
# que otros sistemas puedan asumir que existe.
# En Python sería "status_effects: list = []".
var status_effects: Array = []


# -------------------------------------------------------------------
# CICLO DE VIDA
# -------------------------------------------------------------------

# _ready() se ejecuta al entrar al árbol de escena.
# Si el inspector ya trae un Resource asignado, lo aplicamos.
func _ready() -> void:
	if stats != null:
		setup(stats)


# -------------------------------------------------------------------
# API PÚBLICA
# -------------------------------------------------------------------

# Inicializa (o reinicia) este combatiente a partir de un Resource de stats.
# El TurnManager / CombatScene la llama al arrancar un combate.
func setup(new_stats: CharacterStats) -> void:
	# Guardamos la referencia para poder leer atk/spd/def luego.
	stats = new_stats

	# HP y Éter arrancan al máximo.
	hp_actual = stats.max_hp
	eter_actual = stats.max_eter

	# Reseteo de banderas de combate (por si se reutiliza el nodo).
	is_defending = false
	# clear() es equivalente a "lista.clear()" en Python.
	status_effects.clear()

	# Notificamos a la UI que el HP ya está listo; así las barras se pintan
	# al valor correcto desde el primer frame.
	hp_changed.emit(hp_actual, stats.max_hp)

	print("[Combatant] ", stats.character_name, " listo: ", hp_actual, "/", stats.max_hp)


# Aplica daño entrante. Devuelve la cantidad FINAL aplicada (tras defensa).
# - "amount" es el daño bruto calculado por el atacante (max(1, atk - def)).
# - "damage_type" queda reservado para elementos / Clavo de Ceniza; por
#   ahora solo lo guardamos en logs. Default "fisico".
func take_damage(amount: int, damage_type: String = "fisico") -> int:
	# Si ya está muerto, no aplicamos más daño. Evita "rematar cadáveres"
	# y emisiones duplicadas de la señal "died".
	if not is_alive():
		return 0

	# Partimos del daño bruto que nos pasó el atacante.
	var final_damage: int = amount

	# Defender: reduce al 50%. Usamos ceil() para que nunca sea 0 por redondeo
	# (1 * 0.5 = 0.5 → ceil → 1). Importamos del namespace global, como en Python.
	if is_defending:
		final_damage = int(ceil(final_damage * 0.5))

	# Garantía mínima: todo golpe que impacta debe hacer al menos 1.
	# "max(1, x)" es literalmente igual en Python.
	final_damage = max(1, final_damage)

	# Aplicamos al HP, clampeando en 0 para no ir a negativos.
	hp_actual = max(0, hp_actual - final_damage)

	# Avisamos a la UI: primero damage_taken (para popups), luego hp_changed
	# (para la barra). El orden es intencional: los popups aparecen "antes"
	# de que la barra baje visualmente.
	damage_taken.emit(self, final_damage)
	hp_changed.emit(hp_actual, stats.max_hp)

	# Log de debug con el damage_type, útil cuando metamos elementos.
	print("[Combatant] ", stats.character_name, " recibió ", final_damage, " (", damage_type, "). HP: ", hp_actual, "/", stats.max_hp)

	# Si este golpe lo mata, emitimos "died" una sola vez.
	if hp_actual == 0:
		print("[Combatant] ", stats.character_name, " ha caído.")
		died.emit(self)

	return final_damage


# Cura "amount" puntos sin pasar del máximo. Devuelve cuánto curó de verdad.
# Reservado para Vessa (Paso 6+) y pociones; el Paso 5 aún no la usa en UI.
func heal(amount: int) -> int:
	if not is_alive():
		return 0
	var before: int = hp_actual
	# min(a, b) = el menor; así no pasamos de max_hp.
	hp_actual = min(stats.max_hp, hp_actual + amount)
	var healed: int = hp_actual - before
	hp_changed.emit(hp_actual, stats.max_hp)
	return healed


# ¿Sigue en pie? Lo usan TurnManager (para saltarse turnos de muertos)
# y la IA enemiga (para elegir blancos vivos).
func is_alive() -> bool:
	return hp_actual > 0


# Activa la defensa: el próximo daño recibido se reduce al 50%.
# TurnManager la llama cuando el jugador elige "Defender".
func start_defending() -> void:
	is_defending = true
	print("[Combatant] ", get_display_name(), " se pone en guardia.")


# Desactiva la defensa. TurnManager la llama al inicio del siguiente turno
# de este combatiente, cumpliendo la regla "Defender dura hasta tu próximo
# turno".
func end_defending() -> void:
	if is_defending:
		is_defending = false
		print("[Combatant] ", get_display_name(), " baja la guardia.")


# -------------------------------------------------------------------
# ACCESORES DE CONVENIENCIA
# -------------------------------------------------------------------
# Envuelven lecturas a "stats" con defaults seguros por si stats es null.
# Así el resto del código no tiene que comprobar "if stats != null" cada vez.

# Nombre mostrado en UI y en logs.
func get_display_name() -> String:
	# El operador ternario "a if cond else b" existe igual en Python.
	return stats.character_name if stats != null else "Combatant"


# Velocidad base. El TurnManager la usa para la fórmula de iniciativa.
func get_spd() -> int:
	return stats.spd if stats != null else 0


# Ataque base. El TurnManager lo usa al ejecutar "Atacar".
func get_atk() -> int:
	return stats.atk if stats != null else 0


# Defensa base. La fórmula de daño la resta del ataque del rival.
func get_def() -> int:
	return stats.def if stats != null else 0
