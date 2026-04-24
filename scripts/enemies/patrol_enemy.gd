# Script para un enemigo que patrulla entre varios puntos fijos,
# persigue a Kael si entra en su radio de detección, y al tocarlo
# dispara la señal "combat_triggered" (por ahora solo imprime en consola;
# en el paso 5 conectaremos esta señal a la escena de combate real).
#
# Este script se adjunta a un CharacterBody2D con dos Area2D hijas:
#   - DetectionArea  (círculo grande) → detecta al jugador cerca
#   - ContactArea    (círculo pequeño) → detecta el roce físico que dispara combate
#
# CONCEPTOS NUEVOS vs Kael:
#   - signal: un "evento" que el nodo puede emitir; otros nodos se "suscriben"
#     para reaccionar. Es el patrón "observer" y equivale mentalmente a un
#     callback en Python (tipo "on_click = my_function").
#   - enum: lista de estados con nombre. En Python sería un Enum; aquí es
#     más simple, solo constantes agrupadas.
#   - match: como el "match/case" de Python 3.10+, evita una cascada de "if".

# Heredamos de CharacterBody2D porque el enemigo se mueve con físicas
# (tiene hitbox, colisiona con paredes, empuja cuerpos, etc.).
extends CharacterBody2D


# -------------------------------------------------------------------
# SEÑAL PÚBLICA
# -------------------------------------------------------------------

# Declaramos una señal llamada "combat_triggered" que envía una referencia
# al propio enemigo cuando el combate se dispara. Cualquier nodo externo
# (por ejemplo Main, o un controlador de combate futuro) puede conectarse.
signal combat_triggered(enemy: Node)


# -------------------------------------------------------------------
# ESTADOS DEL ENEMIGO (mini "máquina de estados")
# -------------------------------------------------------------------

# enum crea constantes con nombre. Así PATROL = 0, CHASE = 1, TRIGGERED = 2.
# Usamos nombres en vez de números para que el código sea legible.
enum State { PATROL, CHASE, TRIGGERED }


# -------------------------------------------------------------------
# PARÁMETROS EXPORTADOS (editables desde el inspector de Godot)
# -------------------------------------------------------------------

# Velocidad al patrullar, en píxeles por segundo.
@export var patrol_speed: float = 60.0

# Velocidad al perseguir, un poco mayor para que se sienta amenazante.
@export var chase_speed: float = 110.0

# Distancia en píxeles a la que consideramos que el enemigo "llegó"
# al waypoint actual, para pasar al siguiente. Un valor demasiado bajo
# causaría que oscile alrededor del punto sin llegar nunca.
@export var arrive_threshold: float = 6.0

# Lista de puntos de patrulla, en coordenadas globales (píxeles de pantalla).
# "Array[Vector2]" es una lista tipada: todos los elementos deben ser Vector2.
# En Python sería "list[tuple[float, float]]" con type hints.
# Se pueden editar directamente en el inspector o pasar desde main.tscn.
@export var patrol_points: Array[Vector2] = []


# -------------------------------------------------------------------
# VARIABLES INTERNAS
# -------------------------------------------------------------------

# Estado actual del enemigo; arranca en PATROL.
var _state: int = State.PATROL

# Índice del waypoint al que se dirige ahora mismo (0 = el primero).
var _current_waypoint_index: int = 0

# Referencia al jugador cuando lo tenemos detectado (si no, null).
# La usamos para perseguirlo en el estado CHASE.
var _player: Node2D = null


# -------------------------------------------------------------------
# REFERENCIAS A NODOS HIJOS (se resuelven cuando la escena está lista)
# -------------------------------------------------------------------

# @onready pospone la asignación hasta que _ready() arranca. Si usáramos
# var normal, $DetectionArea sería null porque los hijos aún no existirían.
# "$Nombre" es azúcar para "get_node('Nombre')"; igual que navegar un dict en Python.
@onready var _detection_area: Area2D = $DetectionArea
@onready var _contact_area: Area2D = $ContactArea


# -------------------------------------------------------------------
# CICLO DE VIDA
# -------------------------------------------------------------------

# _ready() se ejecuta cuando el nodo entra en el árbol de escena.
func _ready() -> void:
	# Añadimos el enemigo al grupo "enemies" por si queremos listarlos
	# desde otro sitio (ej. un spawner o una UI con nº de enemigos).
	add_to_group("enemies")

	# Conectamos las señales de las Area2D a nuestras funciones callback.
	# "body_entered" se dispara cuando un PhysicsBody2D (como Kael) entra
	# dentro del área. Esto es como hacer button.on_click = handler en Python.
	_detection_area.body_entered.connect(_on_detection_body_entered)
	_detection_area.body_exited.connect(_on_detection_body_exited)
	_contact_area.body_entered.connect(_on_contact_body_entered)

	# Aviso amarillo si el diseñador olvidó configurar puntos de patrulla.
	# is_empty() en Godot == len(lista) == 0 en Python.
	if patrol_points.is_empty():
		push_warning("[PatrolEnemy] Sin puntos de patrulla: el enemigo se quedará quieto.")

	# Log informativo para ver en la consola cómo arranca.
	print("[PatrolEnemy] Listo en ", global_position, " con ", patrol_points.size(), " puntos de patrulla.")


# _physics_process se ejecuta a una frecuencia fija (60 Hz por defecto)
# y es el sitio adecuado para mover cuerpos físicos.
func _physics_process(delta: float) -> void:
	# "match" elige una rama según el valor de _state.
	# Es más limpio que un "if/elif/elif" largo.
	match _state:
		State.PATROL:
			_update_patrol(delta)
		State.CHASE:
			_update_chase(delta)
		State.TRIGGERED:
			# Si ya disparamos combate, el enemigo se queda quieto
			# hasta que Paso 5 tome el control.
			velocity = Vector2.ZERO

	# Aplicamos la velocidad calculada y dejamos que Godot resuelva
	# colisiones (paredes, el propio Kael, etc.).
	move_and_slide()


# -------------------------------------------------------------------
# LÓGICA DE MOVIMIENTO POR ESTADO
# -------------------------------------------------------------------

# Movimiento tipo "ir al waypoint actual, y cuando llegue saltar al siguiente".
func _update_patrol(_delta: float) -> void:
	# Sin puntos de patrulla no hay nada que hacer; nos quedamos quietos.
	if patrol_points.is_empty():
		velocity = Vector2.ZERO
		return

	# Objetivo: el waypoint actual (la lista se recorre en círculo).
	var target: Vector2 = patrol_points[_current_waypoint_index]

	# Vector que va desde el enemigo hasta el waypoint.
	var to_target: Vector2 = target - global_position

	# Si estamos lo bastante cerca, avanzamos al siguiente waypoint.
	# Usamos length() (magnitud euclídea) y "<=" para la tolerancia.
	if to_target.length() <= arrive_threshold:
		# "%" es el módulo; asegura que el índice vuelve a 0 al pasar del último.
		# Igual que en Python: (i + 1) % len(lista).
		_current_waypoint_index = (_current_waypoint_index + 1) % patrol_points.size()
		velocity = Vector2.ZERO
	else:
		# normalized() devuelve un vector de longitud 1 en la misma dirección.
		# Multiplicado por la velocidad = vector de velocidad correcto.
		velocity = to_target.normalized() * patrol_speed


# Movimiento tipo "ir directo hacia el jugador".
func _update_chase(_delta: float) -> void:
	# Si perdimos la referencia al jugador por algún motivo, volvemos a patrullar.
	if _player == null:
		_state = State.PATROL
		return

	# Vector desde el enemigo hasta el jugador.
	var to_player: Vector2 = _player.global_position - global_position

	# Avanzamos hacia él a velocidad de persecución.
	velocity = to_player.normalized() * chase_speed


# -------------------------------------------------------------------
# CALLBACKS DE SEÑALES (respuestas a eventos)
# -------------------------------------------------------------------

# Se ejecuta cuando un cuerpo físico entra en el radio de detección.
func _on_detection_body_entered(body: Node2D) -> void:
	# Solo nos interesa reaccionar si el cuerpo está en el grupo "player".
	# Así el enemigo no se pone a perseguir otras cosas (otros enemigos, objetos).
	if body.is_in_group("player") and _state != State.TRIGGERED:
		# Guardamos la referencia para perseguirlo en _update_chase().
		_player = body
		_state = State.CHASE
		print("[PatrolEnemy] Kael detectado. Persiguiendo.")


# Se ejecuta cuando un cuerpo físico sale del radio de detección.
func _on_detection_body_exited(body: Node2D) -> void:
	# Si el que sale es el jugador y estábamos persiguiendo, volvemos a patrullar.
	if body.is_in_group("player") and _state == State.CHASE:
		_player = null
		_state = State.PATROL
		print("[PatrolEnemy] Kael fuera de rango. Volviendo a patrullar.")


# Se ejecuta cuando un cuerpo físico entra en el área de contacto (roce físico).
func _on_contact_body_entered(body: Node2D) -> void:
	# Disparamos combate solo si es el jugador y no lo habíamos hecho ya.
	# El chequeo de State.TRIGGERED evita emitir la señal varias veces seguidas.
	if body.is_in_group("player") and _state != State.TRIGGERED:
		_state = State.TRIGGERED
		velocity = Vector2.ZERO
		# Mensaje claro en consola como pidió el diseño del paso 4.
		print("COMBATE INICIADO")
		# Emitimos la señal para que cualquier oyente (por ejemplo Main)
		# pueda reaccionar (más adelante: cambiar a la escena de combate).
		combat_triggered.emit(self)
