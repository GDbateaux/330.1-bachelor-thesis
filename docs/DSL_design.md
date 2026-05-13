# DSL for Cellular Automata

## Example: Game of Life
```
automaton GameOfLife {
    world {
        states {
            Dead
            Alive
        }
        neighborhood: Moore(1)
        dimension: 2
    }


    rules {
        Dead -> Alive when count_neighbors(Alive) == 3
        Alive -> Dead when count_neighbors(Alive) < 2 or count_neighbors(Alive) > 3
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

states_def = "states" "{" identifier { identifier } "}" ;
neighborhood_def = "neighborhood" ":"  neighborhood_type "(" number ")" ;
neighborhood_type = "Moore" | "VonNeumann" ;
dimension_def = "dimension" ":" number ;

(*rules*)
rules_block = "rules" "{" rule {rule} "}" ;
rule = identifier "->" identifier "when" expression ;

(*expression*)
expression = or_expr ;
or_expr = and_expr { "or" and_expr } ;
and_expr = equality { "and" equality } ;
equality = comparison  [ ("==" | "!=") comparison ] ;
comparison = term [ ( "<" | "<=" | ">" | ">=" ) term] ;
term = factor { ( "-" | "+" ) factor } ;
factor = primary  { ( "*" | "/" ) primary} ;
primary = number | function_call | "(" expression ")" | identifier;

function_call = identifier "(" [ arg_list ] ")" ;
arg_list = expression { "," expression } ;

(*numbers / identifiers*)
number = ["+" | "-"] digit { digit } ;
identifier = letter { letter | digit | "_" } ;
letter = "a" | ... | "z" | "A" | ... | "Z" ;
digit = "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" ;
```
