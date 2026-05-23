# DSL for Cellular Automata
This language is designed to model cellular automata in a simple way.

## Structure
Every program is contained in an **automaton block** (`automaton CellularAutomataName {...}`) which contains two other blocks :

### World block (`world { ... }`)

   This block defines the world properties :
   - `states`: A list of states that a cell can hold.
   - `neighborhood`: The proximity model used to calculate a cell's neighbors (`Moore` or `VonNeumann`), followed by its radius in parentheses (e.g. `Moore(1)`).
   - `dimension`: A number to specify the dimensionality of the grid.

### Rules block (`rules { ... }`)

This block defines the rules of the automaton. Each rule describes how a cell changes state.

#### Rule structure

A rule has the following form:
```
StateA -> StateB [when expression] [with prob p]
```
- `StateA`: Current state of the cell
- `StateB`: next state of the cell
- `when`: optional condition that must be true for the transition to occur (e.g. `when count_neighbors(Alive) == 3`)
- `with prob p`: Optional probability (0 <= p <= 1) to inject random behaviors (e.g. `with prob 0.01` means that the transition has a probability of 1% to occur)

## Built-in Function
The following function can be used in the expressions transitions (`when`) :

### count_neighbors (or # shorthand)
Returns the number of neighbors that are currently in the given state. You can either use the count_neighbors(State) function or the shorter prefix #State.

#### Examples
```Alive -> Dead when count_neighbors(Alive) < 2```

```Alive -> Dead when #Alive < 2```

These examples have the same meaning: an Alive cell dies if it has fewer than 2 Alive neighbors.

## Examples
### Example: Game of Life
```
automaton GameOfLife {
    world {
        states { Dead, Alive }
        neighborhood: Moore(1)
        dimension: 2
    }


    rules {
        Dead -> Alive when count_neighbors(Alive) == 3
        Alive -> Dead when count_neighbors(Alive) < 2 or count_neighbors(Alive) > 3
    }
}
```

### Example: Forest Fire
```
automaton ForestFire {
    world {
        states {
            Fire,
            Tree,
            Empty,
            Ash
        }
        neighborhood: VonNeumann(1)
        dimension: 2
    }


    rules {
        Fire -> Ash
        Tree -> Fire when count_neighbors(Fire) > 0
        Tree -> Fire with prob 0.01
        Ash -> Empty when count_neighbors(Fire) == 0
        Empty -> Tree with prob 0.01
    }
}
```

### Example: Wireworld
```
automaton Wireworld {
    world {
        states {
            Empty,
            ElectronHead,
            ElectronTail,
            Conductor
        }
        neighborhood: Moore(1)
        dimension: 2
    }


    rules {
        ElectronHead -> ElectronTail
        ElectronTail -> Conductor
        Conductor -> ElectronHead when #ElectronHead == 1 or #ElectronHead == 2
    }
}
```

### Example: ExcitableMedium
```
automaton ExcitableMedium {
    world {
        states {
            Quiescent,
            Excited,
            Refractory1,
            Refractory2,
            Refractory3,
            Refractory4,
            Refractory5,
            Refractory6
        }
        neighborhood: Moore(1)
        dimension: 2
    }


    rules {
        Quiescent -> Excited when count_neighbors(Excited) > 0
        Excited -> Refractory1
        Refractory1 -> Refractory2
        Refractory2 -> Refractory3
        Refractory3 -> Refractory4
        Refractory4 -> Refractory5
        Refractory5 -> Refractory6
        Refractory6 -> Quiescent
    }
}
```

## EBNF grammar
```ebnf
(*program*)
program = automaton ;
automaton = "automaton" identifier "{" main_block "}" ;
main_block = world_block rules_block ;

(*world*)
world_block = "world" "{" { world_element } "}" ;
world_element = states_def | neighborhood_def | dimension_def ;

states_def = "states" "{" identifier { "," identifier } "}" ;
neighborhood_def = "neighborhood" ":"  neighborhood_type "(" integer ")" ;
neighborhood_type = "Moore" | "VonNeumann" ;
dimension_def = "dimension" ":" integer ;

(*rules*)
rules_block = "rules" "{" {rule} "}" ;
rule = identifier "->" identifier ["when" expression] ["with" "prob" number];

(*expression*)
expression = or_expr ;
or_expr = and_expr { "or" and_expr } ;
and_expr = equality { "and" equality } ;
equality = comparison  [ ("==" | "!=") comparison ] ;
comparison = term [ ( "<" | "<=" | ">" | ">=" ) term] ;
term = factor { ( "-" | "+" ) factor } ;
factor = unary  { ( "*" | "/" ) unary} ;
unary = ["+" | "-"] primary ;
primary = number | function_call | neighbor_shortcut | "(" expression ")" ;
neighbor_shortcut = "#" identifier ;

(*function*)
function_call = identifier "(" [ arg_list ] ")" ;
arg_list = identifier { "," identifier } ;

(*numbers / identifiers*)
number = float | integer ;
float = digit { digit } "." digit { digit } ;
integer = digit { digit } ;
identifier = letter { letter | digit | "_" } ;
letter = "a" | ... | "z" | "A" | ... | "Z" ;
digit = "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" ;
```
