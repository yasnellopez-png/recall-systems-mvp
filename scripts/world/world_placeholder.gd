# Script para dibujar un suelo isométrico "placeholder" (temporal) usando código puro,
# sin necesitar imágenes todavía. Cuando tengamos los tiles reales del pixel art,
# sustituiremos este script por un TileMap de verdad.
#
# Este script se adjunta a un Node2D vacío llamado "World" en main.tscn.
# Dibuja una cuadrícula de rombos (la forma clásica de un tile isométrico)
# usando la función _draw() de Godot.
#
# Conceptos nuevos:
#   - _draw() solo dibuja en 2D; se llama cuando el nodo necesita repintarse.
#   - PackedVector2Array es un array de Vector2 optimizado (como "list[tuple]" en Python pero más rápido).
#   - draw_colored_polygon() dibuja un polígono con un color sólido.

# Heredamos de Node2D porque queremos un nodo 2D que pueda dibujar.
extends Node2D


# -------------------------------------------------------------------
# PARÁMETROS DEL SUELO (configurables desde el inspector)
# -------------------------------------------------------------------

# Cuántos tiles en horizontal (eje X de la cuadrícula lógica).
@export var tiles_x: int = 20

# Cuántos tiles en vertical (eje Y de la cuadrícula lógica).
@export var tiles_y: int = 20

# Ancho de cada tile en píxeles (distancia de punta izquierda a derecha del rombo).
@export var tile_width: float = 64.0

# Alto de cada tile en píxeles. Para un isométrico 2:1 estándar, tile_height = tile_width / 2.
@export var tile_height: float = 32.0

# Colores del patrón de tablero de ajedrez (dos tonos alternos).
# Usamos tonos tierra oscura para que Kael (azul) resalte.
@export var color_a: Color = Color(0.35, 0.30, 0.25, 1.0)
@export var color_b: Color = Color(0.28, 0.23, 0.18, 1.0)

# Color de las líneas del borde de los rombos. Alfa bajo para que se vean sutiles.
@export var grid_line_color: Color = Color(0.0, 0.0, 0.0, 0.25)


# -------------------------------------------------------------------
# FUNCIÓN DE DIBUJO
# -------------------------------------------------------------------

# _draw() se ejecuta cuando Godot pide repintar el nodo.
# Aquí convertimos coordenadas de cuadrícula (x, y enteros) a posiciones
# isométricas en píxeles usando la fórmula clásica:
#   screen_x = (x - y) * tile_width  / 2
#   screen_y = (x + y) * tile_height / 2
func _draw() -> void:
	# Bucles "for" anidados para recorrer toda la cuadrícula.
	# En Python sería "for y in range(tiles_y):" — exactamente la misma idea.
	for y in tiles_y:
		for x in tiles_x:
			# Centro del tile en píxeles (punto medio del rombo).
			var cx: float = (x - y) * tile_width * 0.5
			var cy: float = (x + y) * tile_height * 0.5

			# Los cuatro vértices del rombo (arriba, derecha, abajo, izquierda),
			# empaquetados en un PackedVector2Array que draw_colored_polygon() acepta.
			var points: PackedVector2Array = PackedVector2Array([
				Vector2(cx, cy - tile_height * 0.5),          # Punta superior.
				Vector2(cx + tile_width * 0.5, cy),           # Punta derecha.
				Vector2(cx, cy + tile_height * 0.5),          # Punta inferior.
				Vector2(cx - tile_width * 0.5, cy),           # Punta izquierda.
			])

			# Alternamos entre color_a y color_b para formar un tablero.
			# "(x + y) % 2 == 0" es "si la suma de coordenadas es par".
			# El operador ternario "a if cond else b" existe igual en Python.
			var fill_color: Color = color_a if (x + y) % 2 == 0 else color_b

			# Pintamos el rombo relleno.
			draw_colored_polygon(points, fill_color)

			# Dibujamos el contorno del rombo como 4 segmentos con líneas finas.
			# draw_line(desde, hasta, color, grosor).
			draw_line(points[0], points[1], grid_line_color, 1.0)
			draw_line(points[1], points[2], grid_line_color, 1.0)
			draw_line(points[2], points[3], grid_line_color, 1.0)
			draw_line(points[3], points[0], grid_line_color, 1.0)
