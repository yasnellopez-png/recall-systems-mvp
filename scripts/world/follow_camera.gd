# Script para una Camera2D que sigue a un personaje objetivo (normalmente Kael).
# Se adjuntará al nodo Camera2D en la escena principal (main.tscn).
#
# En GDScript, igual que en Python:
#   - Los comentarios empiezan con "#".
#   - La indentación importa (usa TAB o 4 espacios, no mezclar).
#   - Las funciones se definen con "func" en vez de "def".
# Diferencia clave: aquí heredamos de Camera2D, un nodo de Godot que pinta en pantalla
# "lo que la cámara ve". Es como si fuera el "ojo" del jugador.

# Heredamos de Camera2D. Esto es como "class FollowCamera(Camera2D):" en Python.
extends Camera2D


# -------------------------------------------------------------------
# VARIABLES EXPORTADAS (configurables desde el inspector de Godot)
# -------------------------------------------------------------------

# Ruta al nodo que la cámara debe seguir (por ejemplo "../World/Kael").
# NodePath es un tipo especial de Godot que representa "dirección" dentro del árbol de escena.
# Lo puedes pensar como una ruta de carpetas: "../World/Kael" = sube un nivel, entra en World, coge a Kael.
@export var target_path: NodePath

# Velocidad de suavizado del seguimiento. Más alto = se pega antes al objetivo.
# Godot tiene suavizado integrado en Camera2D; solo le pasamos este número.
@export var smoothing_speed: float = 8.0

# Zoom de la cámara. Vector2(1, 1) es zoom neutro.
# Valores menores (0.5, 0.5) alejan (se ve más mundo),
# valores mayores (2, 2) acercan (se ve menos mundo, más grande el pixel art).
@export var camera_zoom: Vector2 = Vector2(1.0, 1.0)


# -------------------------------------------------------------------
# VARIABLES INTERNAS
# -------------------------------------------------------------------

# Referencia real al nodo que seguimos; la guardamos para no buscarlo cada frame.
# El tipo "Node2D" significa "cualquier nodo 2D con posición". En Python sería
# una variable tipada con un type hint, por ejemplo "target: Node2D = None".
var _target: Node2D = null


# -------------------------------------------------------------------
# FUNCIONES DEL MOTOR
# -------------------------------------------------------------------

# _ready() se ejecuta una sola vez cuando la cámara entra en la escena.
func _ready() -> void:
	# Si nos dieron un target_path válido, buscamos el nodo y lo guardamos.
	# get_node_or_null(ruta) devuelve el nodo si existe, o null si no.
	# En Python sería como "target = cosas.get('kael', None)" (no falla si no está).
	if target_path != NodePath(""):
		_target = get_node_or_null(target_path)

	# Activamos el suavizado de posición integrado de Camera2D.
	# Así la cámara no "pega saltos"; se desliza suavemente hacia el objetivo.
	position_smoothing_enabled = true
	position_smoothing_speed = smoothing_speed

	# Aplicamos el zoom configurado.
	zoom = camera_zoom

	# make_current() le dice a Godot "usa esta cámara para renderizar".
	# Si hay varias Camera2D en la escena, gana la que llame a make_current().
	make_current()


# _process(delta) se ejecuta cada frame gráfico (no físico).
# Para mover la cámara, _process va bien; no necesitamos la precisión de _physics_process.
func _process(_delta: float) -> void:
	# Si el objetivo existe, copiamos su posición global a la cámara.
	# Godot, gracias a position_smoothing_enabled, suavizará el movimiento visual.
	# El "_delta" empieza con guion bajo para indicar "no lo uso, pero lo recibo"
	# (convención común en Godot y Python para parámetros ignorados).
	if _target != null:
		global_position = _target.global_position
