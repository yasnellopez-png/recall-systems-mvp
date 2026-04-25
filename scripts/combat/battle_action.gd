# BattleAction: objeto ligero que describe "qué quiere hacer un combatiente
# en su turno". Atacar, Defender. En pasos futuros: Habilidad, Objeto, Invocar.
#
# Por qué una clase y no un Resource:
#   - Una acción es efímera: se crea, se ejecuta, se tira. No necesitamos
#     que viva en disco como .tres (eso es más propio de datos estáticos
#     tipo CharacterStats).
#   - RefCounted es la clase base más barata de Godot: auto-limpia memoria
#     cuando nadie la referencia, como los objetos normales de Python
#     (que se destruyen cuando pierden todas las referencias).
#
# Paralelo mental con Python:
#   - Es como una @dataclass muy simple, pero sin decorador.
#   - "kind" es un enum entero; en Python sería "from enum import IntEnum".

class_name BattleAction
extends RefCounted


# -------------------------------------------------------------------
# TIPOS DE ACCIÓN
# -------------------------------------------------------------------

# enum: lista de constantes con nombre. ATTACK=0, DEFEND=1.
# Más adelante añadiremos SKILL, ITEM, SUMMON, pero no los declaramos
# todavía para no meter código muerto.
enum Kind { ATTACK, DEFEND }


# -------------------------------------------------------------------
# DATOS DE LA ACCIÓN
# -------------------------------------------------------------------

# Nombre mostrado en botones y logs ("Atacar", "Defender", ...).
var action_name: String = ""

# Qué tipo de acción es. TurnManager hace "match kind" para resolverla.
var kind: int = Kind.ATTACK

# Tipo de daño. Reservado para cuando implementemos los seis elementos
# (Llama Ósea, Vena Pura, etc.) y el sistema del Clavo de Ceniza. Por
# ahora siempre "fisico" y no se usa en cálculos, solo queda en logs.
var damage_type: String = "fisico"


# -------------------------------------------------------------------
# CONSTRUCTOR
# -------------------------------------------------------------------

# _init(...) es el constructor en GDScript; equivale a __init__ en Python.
# Los parámetros tienen valores por defecto, como en Python.
func _init(p_name: String = "", p_kind: int = Kind.ATTACK, p_damage_type: String = "fisico") -> void:
	action_name = p_name
	kind = p_kind
	damage_type = p_damage_type


# -------------------------------------------------------------------
# FÁBRICAS ESTÁTICAS (atajos de uso común)
# -------------------------------------------------------------------
# "static func" es como @staticmethod en Python: no necesita instancia.
# Se llama con "BattleAction.attack()" desde cualquier sitio.
# Así el código cliente queda más legible que "BattleAction.new('Atacar', ...)".

static func attack() -> BattleAction:
	return BattleAction.new("Atacar", Kind.ATTACK, "fisico")


static func defend() -> BattleAction:
	return BattleAction.new("Defender", Kind.DEFEND, "fisico")
