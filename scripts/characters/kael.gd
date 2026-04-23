# Script de movimiento para Kael, el protagonista de Éter Roto.
# Se adjuntará a una escena CharacterBody2D (lo crearemos en el siguiente paso, kael.tscn).
#
# Recordatorio rápido de sintaxis GDScript vs Python:
#   - "extends X" es parecido a "class Kael(X):" en Python: dice de qué clase heredamos.
#   - "var" declara variables (como una variable normal en Python).
#   - "@export" marca la variable para que aparezca editable en el editor de Godot,
#     algo que Python puro no tiene, pero se parece a atributos configurables de una clase.
#   - Las funciones se definen con "func" en vez de "def".
#   - Los dos puntos ":" y la indentación funcionan igual que en Python.
#   - Los tipos (p. ej. ": float") son opcionales pero ayudan a evitar errores; similar a los type hints de Python.

# Heredamos de CharacterBody2D: el nodo estándar para personajes controlados por físicas 2D en Godot 4.
# Nos da "velocity", "move_and_slide()" y detección de colisiones sin que tengamos que programarlas.
extends CharacterBody2D


# -------------------------------------------------------------------
# VARIABLES EXPORTADAS (se podrán cambiar desde el inspector de Godot)
# -------------------------------------------------------------------

# Velocidad máxima del personaje, en píxeles por segundo.
# "@export" es como poner un "slider" en el editor para ajustar sin tocar código.
@export var speed: float = 120.0

# Factor de escala del eje Y para lograr la perspectiva isométrica 2.5D.
# En un isométrico clásico el eje Y se comprime a la mitad (0.5) respecto al eje X,
# así el movimiento vertical parece "alejarse" en vez de subir/bajar verticalmente.
@export var iso_y_scale: float = 0.5

# Qué tan rápido acelera el personaje al empezar a moverse (suaviza el arranque).
@export var acceleration: float = 900.0

# Qué tan rápido frena el personaje al soltar las teclas (suaviza la parada).
@export var friction: float = 1100.0


# -------------------------------------------------------------------
# VARIABLES INTERNAS
# -------------------------------------------------------------------

# Guardamos la última dirección de movimiento para poder usarla luego
# (por ejemplo, para elegir la animación o atacar hacia donde miras).
# Vector2.ZERO es como (0, 0); equivalente a un "tuple" en Python pero con métodos incorporados.
var last_direction: Vector2 = Vector2.DOWN


# -------------------------------------------------------------------
# FUNCIONES DEL MOTOR
# -------------------------------------------------------------------

# _ready() se ejecuta una sola vez cuando el nodo entra en la escena.
# Es el equivalente al "__init__" de una clase en Python, aunque no es constructor real.
func _ready() -> void:
	# Imprime en la consola de Godot para confirmar que Kael está listo.
	# En Python sería "print('Kael listo...')".
	print("Kael listo para moverse en el mundo de Éter Roto.")


# _physics_process(delta) se ejecuta muchas veces por segundo (normalmente 60)
# en el hilo de físicas. Es el lugar ideal para mover personajes.
# "delta" es el tiempo en segundos desde el último frame; sirve para que
# el movimiento sea el mismo en PCs rápidos y lentos.
func _physics_process(delta: float) -> void:
	# Pedimos al usuario una dirección de movimiento basada en las acciones definidas
	# en project.godot ("move_left", "move_right", "move_up", "move_down").
	# Input.get_vector devuelve un Vector2 ya normalizado (longitud 1 como máximo).
	# Similar a leer 4 variables booleanas en Python y armar un vector tú mismo, pero más corto.
	var input_direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# Convertimos la dirección del teclado (cartesiana) a una dirección isométrica.
	# Truco clásico: multiplicar el componente Y por iso_y_scale (normalmente 0.5).
	# Así "arriba" en teclado = "noreste" en pantalla, etc.
	var iso_direction: Vector2 = Vector2(input_direction.x, input_direction.y * iso_y_scale)

	# Si el jugador está empujando alguna tecla (input_direction no es (0,0)):
	if input_direction != Vector2.ZERO:
		# Recordamos la dirección (sin comprimir en Y) para lógica futura
		# como animaciones o ataques direccionales.
		last_direction = input_direction

		# Aceleramos suavemente hacia la velocidad objetivo usando move_toward().
		# move_toward(actual, objetivo, paso) es como decir: "acércate al objetivo
		# como máximo 'paso' unidades"; evita cambios bruscos.
		# La "velocity" es una propiedad heredada de CharacterBody2D.
		velocity = velocity.move_toward(iso_direction * speed, acceleration * delta)
	else:
		# Si no hay input, frenamos suavemente hacia cero.
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	# move_and_slide() es un método integrado de CharacterBody2D:
	# aplica "velocity" automáticamente y maneja las colisiones deslizando
	# el personaje a lo largo de paredes sin que se quede atascado.
	move_and_slide()
