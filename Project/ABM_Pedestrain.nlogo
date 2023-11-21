globals [ view-number ]

turtles-own [
  speed
  left?
  follow?
  already-go-out?
  door
  BNE-type
  nearby-leaders
  leader ; the turtle followed by others (in Pattern: Random follow)
]

patches-own [
  num-here
  num-near
  num-right-remove
  num-left-remove
  N_total          ; the total number of agents that will affect the change of expected comfort utility
  Uec              ; expected comfort utility
  Ues              ; expected society utility
  U_total          ; the sum of distance utility and expected comfort utility
  patch-target     ; the patch with max value of total utility
  Ud_lt            ; distance utility -for the agents moving to the left exit
  Ud_rt            ; distance utility -for the agents moving to the right exit
]

to setup
  ca
  if number-persons = 0 [ user-message " Please set a valid value using the slider 'number-persons' " stop ]
  if weight-Ud + weight-Uec + weight-Ues != 1 [ user-message " Please set a valid weight for summation equal 1 " stop ]
  setup-patches     ; sets the values and colors of the patches
  setup-turtles     ; sets the shapes and colors of the turtles
  Distance-Utility  ; sets the distance utility of each patch
  reset-ticks
end


to go
  if not any? turtles [ print ( word moving-pattern ": " ticks ) stop ]
  ;Export-Views ;; export the model views

  ; Select a moving mode through the chooser "moving-pattern"
  ; a. "BNE (mixed with RF)" - a percentage of turtles will use BNE utility to decide their moving route, and the rest will randomly choose a turtle in view to follow.
  if moving-pattern = "BNE (mixed with RF)" [
    Expected-Uc ; let each patch calculate their expected comfort utiliy
    Expected-Us ; let each patch calculate their expected social utiliy
    BNE-mix-RF
  ]

  ; b. "BNE (mixed with SR)" - a percentage of turtles use BNE to evacuate, and the rest will directly move to the exit.
  if moving-pattern = "BNE (mixed with SR)" [
    Expected-Uc
    Expected-Us
    BNE-mix-SR
  ]

  ; c. "Random follow" - All turtles will randomly choose an agent in view to follow during the simulation.
  if moving-pattern = "Random follow" [
    Expected-Uc
    Expected-Us
    ask turtles [ Random-follow ]
  ]

  ; d. "Shortest route" - All turtles will move directly to the exit.
  if moving-pattern = "Shortest route" [
    Expected-Uc
    Expected-Us
    ask turtles [ Shortest-Route ]
  ]

  already-go-out
  tick
end

;; Moving Pattern: Shortest Route
to Shortest-Route ; turtle procedure
  set-speed
  face door
  fd speed
end

;; Moving-Pattern: Random follow
to Random-follow ; turtle procedure
  set-speed
  find-a-leader
  fd speed
end

;; Find a leader in view to follow
;; Moving Pattern: Random follow
to find-a-leader ; turtle procedure
  let Tx xcor

  ; find the candidate leaders -i.e. neighbors in their views
  ; a. when turtles move to the left
  ifelse left? [
    ; when emergency occurs, the view is narrowed and set to 60 degrees (i.e. area of focus)
    ; the radius (how far turtles can see) is changed by the slider `follow-radius`
    set nearby-leaders turtles in-cone follow-radius 60 with [ xcor < Tx ] ; agents ahead of the turtle
  ]
  ; b. when turtles move to the right
  [ set nearby-leaders turtles in-cone follow-radius 60 with [ xcor > Tx ] ] ; agents in front of the turtle

  ; find a leader -i.e. the nearest neighbor
  if any? nearby-leaders [
    set leader min-one-of nearby-leaders [ distance myself ]
    set follow? true
  ]

  ; Decision-Making Process
  ; if there's a leader:
  ifelse leader != nobody [
    face leader
    ; if the leader is behind the turtle, give it up
    ifelse left? [
      ; a. when moving to the left exit
      if ( [xcor] of leader ) >= Tx [
        set leader nobody
        set follow? false
        face door
      ]
    ]
    ; b. when moving to the right exit
    [
      if ( [xcor] of leader ) <= Tx [
        set leader nobody
        set follow? false
        face door
      ]
    ]
  ]
  ; elsecommands
  ; if there's no leader:
  [ face door ]
end

;; Moving Pattern: BNE (mixed with Random Follow)
to BNE-mix-RF ; turtle procedure
  ; a percetage of turtles will use BNE during simulation (i.e. BNE-type = 1)
  ask turtles with [ BNE-type = 1 ] [
    set color magenta + 2
    BNE-moving
  ]
  ; the rest will randomly choose a turtle in view to follow (i.e. BNE-type = 0)
  ask turtles with [ BNE-type = 0 ] [ Random-follow ]
end

;; Moving Pattern: BNE (mixed with Shortest Route)
to BNE-mix-SR ; turtle procedure
  ; ask a percent of agents use BNE during simulation (i.e. BNE-type = 1)
  ask turtles with [ BNE-type = 1 ] [
    set color orange + 1
    BNE-moving
  ]
  ; the rest will directly move to the exit (i.e. BNE-type = 0)
  ask turtles with [ BNE-type = 0 ] [ Shortest-Route ]
end

;; Moving Pattern: BNE
to BNE-moving ; turtle procedure
  set-speed
  find-a-patch-BNE
  fd speed
end

;; Turltes find the nearby patch with max value of total utility to move
;; Moving Pattern: BNE
to find-a-patch-BNE ; turtle procedure
  ; a. for turtles moving to the left
  ifelse left? [
    ask patch-left [ set U_total (Ud_lt * weight-Ud) + (Uec * weight-Uec) + (Ues * weight-Ues)]
    set patch-target max-one-of patch-left [ U_total ]
  ]
  ; elsecommands
  ; b. for turtles moving to the right
  [
    ask patch-right [ set U_total (Ud_rt * weight-Ud) + (Uec * weight-Uec) + (Ues * weight-Ues)]
    set patch-target max-one-of patch-right [ U_total ]
  ]
  ifelse patch-target != nobody
    [ face patch-target ]
    [ face door ]
end

;; Distance Utility of each patch
;; Moving Pattern: BNE
to Distance-Utility ; patch procedure
  ask patches [
    let DL [ distancexy max-pxcor max-pycor ] of patch min-pxcor min-pycor ; the length of the diagonal
    let D_lt distancexy min-pxcor 0                                        ; the distance to the left exit
    let D_rt distancexy max-pxcor 0                                        ; the distance to the right exit
    set Ud_lt ( 1 - ( D_lt / DL ) )                         ; when turtles moving to the left
    set Ud_rt ( 1 - ( D_rt / DL ) )                          ; when turtles moving to the right
  ]
end


;; Expected comfort utility
;; which is related to the patch density and the probability distribution of turtles moving to it in the next time step.
;; Moving Pattern: BNE
to Expected-Uc ; patch procedure
  let Pm Probability-competing / 100 ; Probablity of moving to the target
  ask patches [
    let px pxcor ; the coord of the patch
    let py pycor
    set num-here count turtles-here ; the number of turtles on this patch
    set num-near count turtles-on neighbors ; the number of turtles on the neighbors

    ;; remove the turtles who have no chance to move to this patch
    ;; a. remove the turtles moving rightwards in patches (px+1, )
    ask neighbors with [ pxcor = px + 1 ] [
      set num-right-remove count turtles-here with [ ( 0 <= heading ) and ( heading < 180 ) ]
    ]
    ;; b. remove the turtle moving leftwards in patches (px-1, )
    ask neighbors with [ pxcor = px - 1 ] [
      set num-left-remove count turtles-here with [ ( 180 <= heading ) and ( heading < 360 ) ]
    ]


    ; the number of turtles that may move to patch (px, py) in the next time step.
    set N_total num-here + num-near - num-right-remove - num-left-remove

    ; Expected Comfort Utility = sum of ( Comfort Utility * corresponding Probability )
    ; i.e. Expected Uc = Uc(0)*P0 + Uc(1)*P1 + ... + Uc(4)*P4

    let P0 ( 1 - Pm ) ^ N_total                                                                                           ; P0 -no turtles will move to this patch in the next time step;
    let P1 N_total * Pm * ( 1 - Pm ) ^ ( N_total - 1 )                                                                    ; P1 -only 1 turtle will enter the patch in the next time step;
    let P2 N_total * ( N_total - 1 ) * 0.5 * ( Pm ^ 2 ) * ( 1 - Pm ) ^ ( N_total - 2 )                                    ; P2 -2 turtles will move to the patch;
    let P3 N_total * ( N_total - 1 ) * ( N_total - 2 ) / 6 * ( Pm ^ 3 ) * ( 1 - Pm ) ^ ( N_total - 3 )                    ; P3 - three turtles will move to patch (px,py)  in the next time step;
    let P4 N_total * ( N_total - 1 ) * ( N_total - 2 ) * ( N_total - 3 ) / 24 * ( Pm ^ 4 ) * ( 1 - Pm ) ^ ( N_total - 4 ) ; P4 -four turtles will enter the patch
    set Uec P0 + P1 + P2 + 0.51 * P3 + 0.07 * P4
  ]
end

;; Expected society utility
;; The calculattion expected value is same as Uec, but changing Us
to Expected-Us ; patch procedure
  let Pm Probability-competing / 100 ; Probablity of moving to the target
  ask patches [
    let px pxcor ; the coord of the patch
    let py pycor
    set num-here count turtles-here ; the number of turtles on this patch
    set num-near count turtles-on neighbors ; the number of turtles on the neighbors

    ;; remove the turtles who have no chance to move to this patch
    ;; a. remove the turtles moving rightwards in patches (px+1, )
    ask neighbors with [ pxcor = px + 1 ] [
      set num-right-remove count turtles-here with [ ( 0 <= heading ) and ( heading < 180 ) ]
    ]
    ;; b. remove the turtle moving leftwards in patches (px-1, )
    ask neighbors with [ pxcor = px - 1 ] [
      set num-left-remove count turtles-here with [ ( 180 <= heading ) and ( heading < 360 ) ]
    ]

    ; the number of turtles that may move to patch (px, py) in the next time step.
    set N_total num-here + num-near - num-right-remove - num-left-remove

    ; Expected Society Utility = sum of (Society Utility * corresponding Probability )
    ;let P0 (1 - Pm) ^ N_total
    ;let P1 N_total * Pm * ((1 - Pm) ^ (N_total - 1))
    let P2 N_total * (N_total - 1) / 2 * (Pm ^ 2) * ((1 - Pm) ^ ( N_total - 2))
    let P3 N_total * (N_total - 1) * (N_total - 2) / 6 * (Pm ^ 3) * ((1 - Pm ) ^ (N_total - 3))
    let P4 N_total * (N_total - 1) * (N_total - 2) * (N_total - 3) / 24 * (Pm ^ 4) * ((1 - Pm) ^ (N_total - 4))
    let P5 N_total * (N_total - 1) * (N_total - 2) * (N_total - 3) * (N_total - 4) / 120 * (Pm ^ 5) * ((1 - Pm) ^ (N_total - 5))
    let P6 N_total * (N_total - 1) * (N_total - 2) * (N_total - 3) * (N_total - 4) * (N_total - 5) / 720 * (Pm ^ 6) * ((1 - Pm) ^ (N_total - 6))
    let P7 N_total * (N_total - 1) * (N_total - 2) * (N_total - 3) * (N_total - 4) * (N_total - 5) * (N_total - 6) / 5040 * (Pm ^ 7) * ((1 - Pm) ^ (N_total - 7))
    ;let P8 N_total * (N_total - 1) * (N_total - 2) * (N_total - 3) * (N_total - 4) * (N_total - 5) * (N_total - 6) * (N_total - 7) / 40320 * (Pm ^ 8) * ((1 - Pm) ^ (N_total - 8))
    set Ues P2 * 0.2 + (P3 + P4) * 0.5 + P5 + P6 + P7
  ]
end

;; moving spped is relevant to the density
;; turtle procedure
to set-speed
  ;; calculate the density of the patch where the turtle's on and the other 8 nearby patches
  let density count turtles-on ( patch-set patch-here neighbors ) / ( 0.7 * 0.7 * 9 )

;  let density count turtles-here / ( 0.7 * 0.7 )  ;; calculate the density of the patch (person/m^2)
  ;; move-speed can be set by the slider 'move-speed'
  if density <= 4 [
    set speed move-speed
  ]
  if density >= 8 [
    set speed  move-speed / 14
  ]
  if density < 8 and density > 4 [
    set speed move-speed * (0.03 * density ^ 2 - 0.64 * density + 3.36  ) / 1.4
  ]
end

; when turtle move rightwards, the patches which will be considered in the next step:
to-report patch-right
  report ( patch-set patch-at 1 0 patch-at 1 1 patch-at 1 -1 )
;  report ( patch-set patch-at 0 1 patch-at 0 -1 patch-at 1 0 patch-at 1 1 patch-at 1 -1 )
end

; when turtle move leftwards, the patches which will be considered in the next step:
to-report patch-left
  report ( patch-set patch-at -1 0 patch-at -1 1 patch-at -1 -1 )
;  report ( patch-set patch-at 0 1 patch-at 0 -1 patch-at -1 0 patch-at -1 1 patch-at -1 -1 )
end

to already-go-out ;; when turtles move out, ask them to die
  ask turtles [
    if distance door < 1 [
      move-to door
      set already-go-out? true
      die
    ]
    if pcolor = red - 1 [
      set already-go-out? true
      die
    ]
  ]
end

;; sets the shape and color of the turtles
to setup-turtles ; turtle procedure
  crt number-persons
  ask turtles [
    set shape "turtle"
    setxy random-xcor random-ycor
    set color green - 3 + random 2
    move-to one-of patches with [ pcolor = grey + 3 ]

    ; a. turtles move to the left
    ifelse random 2 = 0  [
      set left? true
      set heading 180 + ( random-float 180 )
      set door one-of patches with [
        pxcor = min-pxcor and pcolor = red - 1
      ]
    ]
    ; b. turtles move to the right
    [
      set left? false
      set heading 0 + ( random-float 180 )
      set door one-of patches with [
        pxcor = max-pxcor and pcolor = red - 1
      ]
    ]

    set BNE-type 0
    set leader nobody
    set follow? false
  ]

  ; set a percetage of turtles using BNE (BNE-type = 1) to evacuate
  ask n-of ( number-persons * Percentage-of-agents-with-BNE / 100 ) turtles
    [ set BNE-type 1 ]
end

;; setup patches
to setup-patches ; patch procedure
  resize-world -10 10 -5 5 ; set size of world
  ask patches [ set pcolor grey + 3 ]

  ; setup the exits
  ask patches with [ abs pxcor = max-pxcor and abs pycor <= ( door-width / 3 ) ]
    [ set pcolor red - 1 ]
end

;; export view every 10 ticks
to Export-Views
  file-open "D:/GitRepo/GT_Course/Project/img/"
  if ticks mod 5 = 0 [
    set view-number view-number + 1
    export-view (word "/img/" moving-pattern "_tricks" ticks ".png")
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
24
11
452
240
-1
-1
20.0
1
10
1
1
1
0
0
0
1
-10
10
-5
5
1
1
1
ticks
30.0

BUTTON
468
15
638
48
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
468
54
547
87
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
554
56
635
89
goonce
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
24
246
283
279
number-persons
number-persons
0
500
500.0
1
1
persons
HORIZONTAL

PLOT
663
10
1161
212
Number of turtles in the tunnel
Evacuation time
Number of turtles
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count turtles"

SLIDER
23
360
150
393
door-width
door-width
1
5
4.0
1
1
NIL
HORIZONTAL

SLIDER
23
403
150
436
Step-length
Step-length
0
1
0.7
0.1
1
m
HORIZONTAL

SLIDER
163
359
288
392
move-speed
move-speed
0
4
2.2
0.1
1
m/s
HORIZONTAL

SLIDER
159
404
285
437
follow-radius
follow-radius
0
5
4.0
1
1
NIL
HORIZONTAL

PLOT
664
221
1163
447
[Mean] Utilities of turtles in the tunnel
Evacuation time
Total Utility 
0.0
10.0
0.0
1.0
true
false
"" "ask turtles [ if pcolor = red + 1 [ pen-down ] ]"
PENS
"Mean U_sum" 1.0 0 -16777216 true "" "plot mean [U_total] of patches"

SLIDER
25
281
284
314
Percentage-of-agents-with-BNE
Percentage-of-agents-with-BNE
0
100
100.0
0.1
1
%
HORIZONTAL

SLIDER
23
317
282
350
Probability-competing
Probability-competing
0
100
16.8
0.1
1
%
HORIZONTAL

CHOOSER
299
254
469
299
moving-pattern
moving-pattern
"BNE (mixed with RF)" "BNE (mixed with SR)" "Random follow" "Shortest route"
1

SLIDER
298
307
470
340
weight-Ud
weight-Ud
0
1
0.3
0.01
1
NIL
HORIZONTAL

SLIDER
298
350
470
383
weight-Uec
weight-Uec
0
1
0.5
0.01
1
NIL
HORIZONTAL

SLIDER
298
395
470
428
weight-Ues
weight-Ues
0
1
0.2
0.01
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="mix_BNE_SR" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>ticks</metric>
    <enumeratedValueSet variable="Probability-competing">
      <value value="16.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="follow-radius">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="weight-Uec">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="weight-Ud">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="moving-pattern">
      <value value="&quot;BNE (mixed with SR)&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="weight-Ues">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="move-speed">
      <value value="2.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-persons">
      <value value="100"/>
      <value value="200"/>
      <value value="300"/>
      <value value="400"/>
      <value value="500"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Percentage-of-agents-with-BNE" first="91" step="1" last="100"/>
    <enumeratedValueSet variable="door-width">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Step-length">
      <value value="0.7"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="mix_BNE_RF" repetitions="5" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="Probability-competing">
      <value value="16.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="follow-radius">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="weight-Uec">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="weight-Ud">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="moving-pattern">
      <value value="&quot;BNE (mixed with RF)&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="weight-Ues">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="move-speed">
      <value value="2.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-persons">
      <value value="100"/>
      <value value="200"/>
      <value value="300"/>
      <value value="400"/>
      <value value="500"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Percentage-of-agents-with-BNE" first="0" step="1" last="10"/>
    <enumeratedValueSet variable="door-width">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Step-length">
      <value value="0.7"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="mix_BNE_RF2" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <enumeratedValueSet variable="Probability-competing">
      <value value="16.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="follow-radius">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="weight-Uec">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="weight-Ud">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="moving-pattern">
      <value value="&quot;BNE (mixed with RF)&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="weight-Ues">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="move-speed">
      <value value="2.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-persons">
      <value value="500"/>
    </enumeratedValueSet>
    <steppedValueSet variable="Percentage-of-agents-with-BNE" first="51" step="1" last="60"/>
    <enumeratedValueSet variable="door-width">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Step-length">
      <value value="0.7"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="RF" repetitions="20" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <enumeratedValueSet variable="Probability-competing">
      <value value="16.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="follow-radius">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="weight-Ud">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="weight-Uec">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="weight-Ues">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="move-speed">
      <value value="2.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="moving-pattern">
      <value value="&quot;BNE (mixed with RF)&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-persons">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-agents-with-BNE">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="door-width">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Step-length">
      <value value="0.7"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="Probability-competing">
      <value value="16.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="follow-radius">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="weight-Ud">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="weight-Uec">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="weight-Ues">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="move-speed">
      <value value="2.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="moving-pattern">
      <value value="&quot;BNE (mixed with RF)&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-persons">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-agents-with-BNE">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="door-width">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Step-length">
      <value value="0.7"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="BNE" repetitions="20" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="Probability-competing">
      <value value="16.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="follow-radius">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="weight-Ud">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="weight-Uec">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="weight-Ues">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="move-speed">
      <value value="2.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="moving-pattern">
      <value value="&quot;BNE (mixed with SR)&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-persons">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Percentage-of-agents-with-BNE">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="door-width">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Step-length">
      <value value="0.7"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
