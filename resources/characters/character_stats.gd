# Resource que describe los stats base de un personaje o enemigo de Éter Roto.
#
# ¿Qué es un "Resource" en Godot?
#   - Es una clase de datos serializable: vive en un archivo .tres editable
#     en el inspector. La idea es la misma que un dataclass de Python:
#     un envoltorio de datos con tipos, sin lógica pesada.
#   - En Python sería algo como:
#         @dataclass
#         class CharacterStats:
#             character_name: str = ""
#             max_hp: int = 1
#             ...
#     pero guardado en disco para poder editarlo a mano desde Godot.
#
# Por qué un Resource y no una variable hardcoded:
#   - Mañana queremos balancear stats sin tocar código: editas el .tres y listo.
#   - Mismo Resource sirve para Kael, Lyra, Vessa, Oryn, enemigos y placeholders.

# "class_name" registra esta clase globalmente; así desde otros scripts puedo
# escribir "var s: CharacterStats = ..." sin necesidad de "preload".
# Es como si en Python hubiera un módulo importado en todas partes.
class_name CharacterStats
extends Resource


# -------------------------------------------------------------------
# DATOS DE IDENTIDAD
# -------------------------------------------------------------------

# Nombre mostrado en UI. Lo llamo "character_name" y no "name" para no
# colisionar con propiedades internas de Node/Resource en futuras refactors.
@export var character_name: String = ""


# -------------------------------------------------------------------
# STATS DE COMBATE (los que SÍ se usan en el Paso 5)
# -------------------------------------------------------------------

# Puntos de vida máximos. El HP actual vive en Combatant, no aquí
# (este recurso es solo la "plantilla" inmutable).
@export var max_hp: int = 1

# Ataque base. Se usa en la fórmula: daño = max(1, atk - def_efectiva).
@export var atk: int = 1

# Velocidad. Determina la iniciativa al inicio de cada ronda:
#   iniciativa = spd + randi_range(0, spd / 4)
@export var spd: int = 1

# Defensa base. La fórmula ya la prevé, aunque por ahora todos llevan 0.
@export var def: int = 0


# -------------------------------------------------------------------
# CAMPOS RESERVADOS PARA PASOS FUTUROS (no se usan todavía)
# -------------------------------------------------------------------
# Importante: los dejamos declarados para que el .tres ya los traiga,
# y para que la arquitectura de combate no asuma su ausencia.

# Éter máximo. El Éter es el "MP" del juego; las invocaciones del Paso 7+
# serán hechizos de coste alto de Éter (NO una barra que se llena con daño).
@export var max_eter: int = 0

# Elementos a los que este personaje/enemigo es débil (recibe 1.5×).
# Solo nombres por ahora; el sistema de seis elementos llega en otro paso.
# "Array[String]" es una lista tipada; el equivalente Python sería "list[str]".
@export var elementos_debiles: Array[String] = []

# Elementos a los que resiste (recibe 0.5×).
@export var elementos_resistentes: Array[String] = []
