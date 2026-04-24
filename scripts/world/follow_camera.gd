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

# Si target_path falla o está vacío, la cámara buscará un nodo con este nombre en toda la escena.
# Útil como "red de seguridad" si se te olvida asignar el target en el editor.
@export var fallback_target_name: String = "Kael"

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
	# ---- DIAGNÓSTICO: imprime en la consola "Output" de Godot ----
	# Así, al correr el juego, vemos exactamente qué encuentra la cámara.
	# "%" y "%s" funcionan como el "f-string" de Python pero con sintaxis vieja tipo "printf".
	print("[FollowCamera] Arrancando. Mi ruta en el árbol es: ", get_path())
	print("[FollowCamera] target_path configurado en el inspector: '", target_path, "'")

	# -------------------------------------------------------------
	# INTENTO 1: usar el target_path que viene del editor (main.tscn).
	# -------------------------------------------------------------
	# get_node_or_null(ruta) devuelve el nodo si existe, o null si no.
	# En Python sería como "target = cosas.get('kael', None)" (no falla si no está).
	if target_path != NodePath(""):
		_target = get_node_or_null(target_path)
		if _target != null:
			print("[FollowCamera] OK - Objetivo encontrado por target_path: ", _target.get_path())
		else:
			# push_warning() muestra un aviso amarillo en el panel "Debugger" de Godot.
			push_warning("[FollowCamera] AVISO - target_path no resolvió a ningún nodo: '%s'" % target_path)

	# -------------------------------------------------------------
	# INTENTO 2 (fallback): buscar por nombre en todo el árbol.
	# -------------------------------------------------------------
	# Si el primer intento no funcionó, recorremos la escena buscando un
	# Node2D que se llame como "fallback_target_name" (por defecto "Kael").
	# Así la cámara sigue funcionando aunque el path esté mal o vacío.
	if _target == null:
		print("[FollowCamera] Fallback: buscando Node2D llamado '", fallback_target_name, "' en toda la escena...")
		_target = _find_node2d_by_name(get_tree().root, fallback_target_name)
		if _target != null:
			print("[FollowCamera] OK - Objetivo encontrado por fallback: ", _target.get_path())

	# Si después de ambos intentos seguimos sin objetivo, avisamos fuerte.
	# push_error() muestra un error rojo en el panel de errores.
	if _target == null:
		push_error("[FollowCamera] ERROR - No se encontró objetivo; la cámara se quedará quieta.")

	# -------------------------------------------------------------
	# Configuración visual de la cámara (igual que antes).
	# -------------------------------------------------------------
	# position_smoothing_enabled activa el suavizado integrado de Camera2D.
	# Sin esto, la cámara pegaría saltos bruscos al seguir al personaje.
	position_smoothing_enabled = true
	position_smoothing_speed = smoothing_speed

	# Aplicamos el zoom configurado.
	zoom = camera_zoom

	# make_current() le dice a Godot "usa esta cámara para renderizar".
	# Si hay varias Camera2D en la escena, gana la que llame a make_current().
	make_current()

	# -------------------------------------------------------------
	# Posición inicial = sobre el objetivo.
	# -------------------------------------------------------------
	# Si no hacemos esto, la cámara aparece en (0,0) y "navega" hasta
	# llegar al personaje durante el primer segundo de juego.
	# Al colocarla directamente sobre el objetivo, evitamos ese efecto raro.
	if _target != null:
		global_position = _target.global_position
		# reset_smoothing() limpia el histórico de suavizado para que el
		# "teletransporte" inicial no genere una interpolación al arrancar.
		reset_smoothing()


# _process(delta) se ejecuta cada frame gráfico (no físico).
# Para mover la cámara, _process va bien; no necesitamos la precisión de _physics_process.
func _process(_delta: float) -> void:
	# Si el objetivo existe, copiamos su posición global a la cámara.
	# Godot, gracias a position_smoothing_enabled, suavizará el movimiento visual.
	# El "_delta" empieza con guion bajo para indicar "no lo uso, pero lo recibo"
	# (convención común en Godot y Python para parámetros ignorados).
	if _target != null:
		global_position = _target.global_position


# -------------------------------------------------------------------
# HELPERS PRIVADOS
# -------------------------------------------------------------------

# Busca recursivamente un Node2D por nombre en el árbol de escena.
# "recursivamente" significa que también revisa a todos los hijos, y los hijos
# de los hijos, etc. En Python sería la misma idea con un "def find(root, name):".
# Devuelve el primero que encuentre, o null si no existe.
func _find_node2d_by_name(root: Node, wanted_name: String) -> Node2D:
	# Caso base: ¿este mismo nodo cumple? Debe llamarse igual Y ser Node2D.
	# "root is Node2D" es como isinstance(root, Node2D) en Python.
	if root.name == wanted_name and root is Node2D:
		return root as Node2D
	# Caso recursivo: preguntamos a cada hijo.
	for child in root.get_children():
		var found: Node2D = _find_node2d_by_name(child, wanted_name)
		if found != null:
			return found
	# Si nadie cumple, devolvemos null.
	return null
