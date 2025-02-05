breed [atoms atom]
breed [force-arrows force-arrow]

atoms-own [
  fx     ; x-component of force vector
  fy     ; y-component of force vector
  prev-x
  prev-y
  vx     ; x-component of velocity vector
  vy     ; y-component of velocity vector
  posi ; atom position. options: urc (upper right corner), ur (upper right), lr (lower right), lrc (lower right corner),
           ; b (bottom), llc (lower left corner), ll (lower left), ul (upper left), ulc (upper left corner), t (top)
  mass
  PotE
  calc-vx
  calc-vy
]

force-arrows-own [
  my-atom ; the atom that the force-arrow is indicating the force on
]

globals [
  diameter
  r-min
  eps
  sigma
  cutoff-dist
  time-step
  sqrt-2-kb-over-m  ;hmm should probably change if mass is changed
  cone-check-dist
  num-atoms
  f-app-per-atom
  f-app-vert-per-atom
  vert-force-count
  new-fx
  new-fy
]

;;;;;;;;;;;;;;;;;;;;;;
;; Setup Procedures ;;
;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  ifelse crystal-view = "small-atoms" [
    set diameter .6 ]
    [set diameter .9]
  set r-min 1
  set eps .07 ;.1 ;  1
  set sigma .907 ;; .89090
  set cutoff-dist 5 * r-min ;5
  set time-step .15 ;.03 ; .3 max
  set sqrt-2-kb-over-m (1 / 20)
  set cone-check-dist 1.5
  set num-atoms atoms-per-row * atoms-per-column
  setup-atoms
  setup-force-arrows
  setup-links
  if crystal-view = "hide-atoms" [
    ask atoms [ hide-turtle ]
  ]
  init-velocity
  reset-timer
  reset-ticks
end

to setup-atoms
  create-atoms num-atoms [
    set shape "circle"
    set size diameter
    set color blue
    set mass 1
  ]
    let len atoms-per-row
    let x-dist r-min
    let y-dist sqrt (x-dist ^ 2 - (x-dist / 2) ^ 2)
    let ypos (- len * x-dist / 2) ;the y position of the first atom
    let xpos (- len * x-dist / 2) ;the x position of the first atom
    let rnum 0
    ask atoms [
      if xpos >= (len * x-dist / 2)  [
        set rnum rnum + 1
        set xpos (- len * x-dist / 2) + (rnum mod 2) * x-dist / 2
        set ypos ypos + y-dist
      ]
      setxy xpos ypos
      set xpos xpos + x-dist
    ]

  let ymax [ycor] of one-of atoms with-max [ycor]
  let xmax [xcor] of one-of atoms with-max [xcor]
  let ymin [ycor] of one-of atoms with-min [ycor]
  let xmin [xcor] of one-of atoms with-min [xcor]
  let median-xcor (median [xcor] of atoms)
  let median-ycor (median [ycor] of atoms)
  let sectioning-value round (len / 4 )

  let even-offset-adjust 0
  if atoms-per-column mod 2 = 0
  [ set even-offset-adjust x-dist / 2 ]

  ask atoms [
    (ifelse ycor = ymin [
      (ifelse xcor >= xmin and xcor < median-xcor - sectioning-value [
        set posi "llc"
       ]
       xcor > median-xcor - sectioning-value and xcor < median-xcor + sectioning-value [
        set posi "b"
       ]
       [ set posi "lrc" ])
    ]
    ycor = ymax [
      (ifelse xcor >= xmin + even-offset-adjust and xcor < median-xcor - sectioning-value + even-offset-adjust [
        set posi "ulc"
      ]
      xcor > median-xcor - sectioning-value + even-offset-adjust and xcor < median-xcor + sectioning-value + even-offset-adjust [
        set posi "t"
      ]
      [ set posi "urc" ])
    ]
    xcor = xmin or xcor = xmin + (1 / 2) [
      (ifelse ycor < ymax and ycor >= median-ycor [
        set posi "ul"
      ]
      ycor > ymin and ycor < median-ycor [
        set posi "ll"
      ])
    ]
    xcor = xmax or xcor = xmax - (1 / 2) [
      (ifelse ycor < ymax and ycor >= median-ycor [
        set posi "ur"
      ]
      ycor > ymin and ycor < median-ycor [
        set posi "lr"
      ])
    ]
    [set posi "body"])
  ]

  ask atoms [
    set prev-x xcor
    set prev-y ycor
  ]

  if create-dislocation? [
    let curr-y-cor median-ycor
    let curr-x-cor median-xcor
    while [ curr-y-cor <= ceiling (ymax) ] [
      ask atoms with [xcor <= curr-x-cor + x-dist * .75
        and xcor >= curr-x-cor
        and ycor <= curr-y-cor + y-dist * .75
        and ycor >= curr-y-cor ] [ die ]
      set curr-y-cor curr-y-cor + y-dist
      set curr-x-cor curr-x-cor - x-dist / 2
    ]
   ]
end

to setup-links
  ask atoms [
    if diagonal-right-links [
      set heading 330
      link-with-atoms-in-cone-setup
      ]
    if diagonal-left-links [
      set heading 30
      link-with-atoms-in-cone-setup
      ]
    if horizontal-links [
      set heading 90
      link-with-atoms-in-cone-setup
     ]
  ]
  ask links [
    set thickness .25
    color-links link-length
  ]
end

to link-with-atoms-in-cone-setup
  if any? atoms in-cone cone-check-dist 15 [
        create-links-with other atoms in-cone cone-check-dist 15
       ]
end

to setup-force-arrows
  ifelse force-mode = "Shear" [
    set f-app-per-atom f-app / (ceiling ( atoms-per-column / 2 ) - 1)
    set f-app-vert-per-atom ((f-app-vert / 100) / atoms-per-row)
    create-force-arrows atoms-per-row + ceiling ( atoms-per-column / 2 ) - 1 [
      set shape "arrow"
      set color white
    ]

    ask atoms with [posi = "ulc" or posi = "t" or posi = "urc"] [
      ask one-of force-arrows with [xcor = 0 and ycor = 0] [
        set xcor [xcor] of myself
        set ycor [ycor] of myself + 2
        set my-atom [who] of myself
        set size sqrt(f-app-vert-per-atom * 100)
        face myself
      ]
    ]
    ask atoms with [posi = "ul"] [
      ask one-of force-arrows with [xcor = 0 and ycor = 0] [
        set xcor [xcor] of myself - 2
        set ycor [ycor] of myself
        set my-atom [who] of myself
        set size sqrt(f-app-per-atom)
        face myself
      ]
    ]
  if create-dislocation? [
      ask force-arrows with [xcor = 0 and ycor = 0] [ die ]
    ]
  ]
  [
    set vert-force-count count atoms with [posi = "urc" or posi = "lrc" or posi = "ulc" or posi = "llc" ]
    set f-app-per-atom  f-app / (2 * atoms-per-column - 4)
    set f-app-vert-per-atom (f-app-vert / 100) / vert-force-count

    create-force-arrows 2 * atoms-per-column - 4 + vert-force-count [
      set shape "arrow"
      set color white ]

    ask atoms with [posi = "ulc" or posi = "urc" or posi = "llc" or posi = "lrc"] [
      ask one-of force-arrows with [xcor = 0 and ycor = 0] [
        set my-atom [who] of myself
        set size sqrt(f-app-vert-per-atom * 100)
        set xcor [xcor] of myself
        ifelse [posi] of myself = "ulc" or [posi] of myself = "urc" [
          set ycor [ycor] of myself + 2
          ]
          [ set ycor [ycor] of myself - 2 ]
        face myself
      ]
    ]
    ask atoms with [posi = "ul" or posi = "ll" or posi = "ur" or posi = "lr"] [
      ask one-of force-arrows with [xcor = 0 and ycor = 0] [
        set size sqrt(f-app-per-atom)
        set my-atom [who] of myself
        set ycor [ycor] of myself
        ifelse [posi] of myself = "ul" or [posi] of myself = "ll" [
          set xcor [xcor] of myself - 2
        ]
        [ set xcor [xcor] of myself + 2 ]
        face myself
        rt 180
      ]
    ]
  ]
end

to init-velocity
  let v-avg sqrt-2-kb-over-m * sqrt system-temp
  ask atoms [
    let x-y-split random-float 1
    set vx v-avg * x-y-split * positive-or-negative
    set vy v-avg * (1 - x-y-split) * positive-or-negative]
end

to-report positive-or-negative
  report ifelse-value random 2 = 0 [-1] [1]
end

;;;;;;;;;;;;;;;;;;;;;;;;
;; Runtime Procedures ;;
;;;;;;;;;;;;;;;;;;;;;;;;

to go
  ;control-temp
  if any? links [
    ask links [die]
  ]
  ask atoms [
    move
  ]
  ask atoms [
    update-force-and-velocity
  ]
;  ask atoms [
;    move
;  ]
;  if any? links [
;    ask links [
;;      set thickness .25
;      color-links link-length]
;  ]
  tick-advance time-step
  update-plots
end

to move  ; atom procedure, uses velocity-verlet algorithm
    ifelse force-mode = "Shear" [
      if posi != "ll" and posi != "lr" [
;        let temp-x xcor
;        let temp-y ycor
        set xcor velocity-verlet-pos xcor vx (fx / mass)
        set ycor velocity-verlet-pos ycor vy (fy / mass)
;        set fx new-fx
;        set fy new-fy
;        set vx (xcor - temp-x) / time-step
;        set vy (ycor - temp-x) / time-step
;        let new-xcor verlet-pos xcor prev-x fx
;        let new-ycor verlet-pos ycor prev-y fy
;        set vx (new-xcor - xcor) / time-step
;        set vy (new-ycor - ycor) / time-step
;        set prev-x xcor
;        set prev-y ycor
;        set xcor new-xcor
;        set ycor new-ycor
        (ifelse posi = "ul" [
          ask force-arrows with [my-atom = [who] of myself] [
            set xcor [xcor] of myself - 2
            set size sqrt( f-app-per-atom )
          ]
        ]
        posi = "ulc" or posi = "t" or posi = "urc" [
            ask force-arrows with [my-atom = [who] of myself] [
              set xcor [xcor] of myself
              set size sqrt(f-app-vert-per-atom * 100)
          ]
        ])
        if xcor > max-pxcor [
            if posi = "ul" or posi = "ulc" or posi = "t" or posi = "urc" [
              ask force-arrows with [my-atom = [who] of myself] [die]
          ]
         die
        ]
      ]
    ]
    [ ;; force-mode = "Tension"
;       let temp-x xcor
;       let temp-y ycor
      set xcor velocity-verlet-pos xcor vx (fx / mass)
      set ycor velocity-verlet-pos ycor vy (fy / mass)

;      set vx (xcor - prev-x) / time-step
;      set vy (ycor - prev-y) / time-step
;      let new-xcor verlet-pos xcor prev-x fx
;      let new-ycor verlet-pos ycor prev-y fy

;      set prev-x xcor
;      set prev-y ycor
;      set xcor new-xcor
;      set ycor new-ycor
;        set calc-vx (xcor - temp-x) / time-step
;        set calc-vy (ycor - temp-x) / time-step
      (ifelse posi = "ul" or posi = "ll" or posi = "ur" or posi = "lr" [
          ask force-arrows with [my-atom = [who] of myself] [
            set size sqrt(f-app-per-atom)
            set ycor [ycor] of myself
            ifelse [posi] of myself = "ul" or[posi] of myself = "ll" [
              set xcor [xcor] of myself - 2
            ]
            [ set xcor [xcor] of myself + 2 ]
          ]
         ]
        posi = "ulc" or posi = "urc" or posi = "llc" or posi = "lrc" [
            ask force-arrows with [my-atom = [who] of myself] [
              set size sqrt(f-app-vert-per-atom * 100)
              set xcor [xcor] of myself
              ifelse [posi] of myself = "ulc" or [posi] of myself = "urc" [
                set ycor [ycor] of myself + 2
              ]
              [ set ycor [ycor] of myself - 2 ]
            ]
          ])
      if xcor > max-pxcor or xcor < min-pycor [
        if posi = "ul" or posi = "ll" or posi = "ur" or posi = "lr" [
        ask force-arrows with [my-atom = [who] of myself] [die]
      ]
      die
     ]
   ]
end


to update-force-and-velocity
;  let new-fx 0
;  let new-fy 0
  set new-fx 0
  set new-fy 0
  set PotE 0
  let total-force 0
  let in-radius-atoms (other atoms in-radius cutoff-dist)
  ask in-radius-atoms [
    let r distance myself
    let force LJ-force r
    set PotE PotE + LJ-pot r
    set total-force total-force + abs(force)
    face myself
    set new-fx new-fx + (force * dx)
    set new-fy new-fy + (force * dy)
    ]

  (ifelse force-mode = "Shear" [
      (ifelse posi = "ul" [
        set new-fx report-new-force posi new-fx
      ]
      posi = "ulc" or posi = "t" or posi = "urc" [
        set new-fy report-new-force posi new-fy
      ])
   ]
  force-mode = "Tension" [
      (ifelse posi = "ul" or posi = "ll" or posi = "ur" or posi = "lr" [
        set new-fx report-new-force posi new-fx
      ]
      posi = "ulc" or posi = "urc" or posi = "llc" or posi = "lrc" [
        set new-fy report-new-force posi new-fy
      ])
   ])

   set vx velocity-verlet-velocity vx (fx / mass) (new-fx / mass)
   set vy velocity-verlet-velocity vy (fy / mass) (new-fy / mass)
   set fx new-fx
   set fy new-fy

   if update-color? [
    set-color total-force
  ]

    if diagonal-right-links [
      set heading 330
      link-with-atoms-in-cone in-radius-atoms
      ]
    if diagonal-left-links [
      set heading 30
      link-with-atoms-in-cone in-radius-atoms
      ]
    if horizontal-links [
      set heading 90
      link-with-atoms-in-cone in-radius-atoms
      ]
  if any? links [
   ask links [
;      set thickness .25
      color-links link-length]
  ]
end

to link-with-atoms-in-cone [atom-set]
  let in-cone-atoms (atom-set in-cone cone-check-dist 60)
    if any? in-cone-atoms [
      create-link-with min-one-of in-cone-atoms [distance myself]
    ]
end

to-report report-new-force [ pos f-gen ]
  (ifelse force-mode = "Shear" [
    set f-app-per-atom f-app / (ceiling ( atoms-per-column / 2 ) - 1)
    set f-app-vert-per-atom ((f-app-vert / 100) / atoms-per-row)
     (ifelse pos = "ul" [
       report f-gen + f-app-per-atom
      ]
      pos = "ulc" or pos = "t" or pos = "urc" [
        report f-gen - f-app-vert-per-atom
      ])
   ]
  force-mode = "Tension" [
    set f-app-per-atom  f-app / (2 * atoms-per-column - 4)
    set f-app-vert-per-atom (f-app-vert / 100) / vert-force-count
     (ifelse pos = "ul" or pos = "ll" [
       report f-gen - f-app-per-atom
      ]
     pos = "ur" or pos = "lr" [
       report f-gen + f-app-per-atom
      ]
     pos = "ulc" or pos = "urc"  [
       report f-gen - f-app-vert-per-atom
      ]
     pos = "llc" or pos = "lrc"  [
       report f-gen + f-app-vert-per-atom
     ])
    ])
end

to-report LJ-force [ r ]
  report (48 * eps / r )* ((sigma / r) ^ 12 - (1 / 2) * (sigma / r) ^ 6)
end

to control-temp
  let current-v-avg mean [ sqrt (vx ^ 2 + vy ^ 2)] of atoms
  let target-v-avg sqrt-2-kb-over-m * sqrt system-temp
  if current-v-avg != 0 [
    ask atoms [
      set vx vx * (target-v-avg / current-v-avg)
      set vy vy * (target-v-avg / current-v-avg)
    ]
  ]
end

to-report velocity-verlet-pos [pos v a]  ; position, velocity and acceleration
  report pos + v * time-step + (1 / 2) * a * (time-step ^ 2)
end

to-report velocity-verlet-velocity [v a new-a]  ; position and velocity
  report v + (1 / 2) * (new-a + a) * time-step
end

to-report verlet-pos [x px new-a]
  report (2 * x) - px + new-a * (time-step ^ 2)
end

to set-color [v]
  set color scale-color blue sqrt(v) -.3 1.4
end

to color-links [len]
  (ifelse len < .995 [
    set color scale-color red sqrt (.995 - len) -.05 .35
    set thickness (.25 + (.995 - len))]

    len > 1.018073 [
      set color scale-color yellow sqrt (len - 1.018073) -.05 .35
      set thickness (.25 - (len - 1.018073))] ;; equilibrium bond length
    [set color gray
    set thickness .25 ]
    )

;  (ifelse len < .995 [
;    set color scale-color red sqrt (.995 - len) -.05 .35
;    set thickness (.25 - ((.995 - len)) ^ 2 )]
;
;    len > 1.018073 [
;      set color scale-color yellow sqrt (len - 1.018073) -.05 .35
;      set thickness (.25 + (len - 1.018073) ^ 2)] ;; equilibrium bond length
;    [set color gray
;    set thickness .25 ]
;    )

;  (ifelse len < .995 [
;    set color scale-color red sqrt (.995 - len) -.05 .35
;    set thickness (.25 - sqrt((.995 - len)) )]
;
;    len > 1.018073 [
;      set color scale-color yellow sqrt (len - 1.018073) -.05 .35
;      set thickness (.25 + sqrt(len - 1.018073))] ;; equilibrium bond length
;    [set color gray
;    set thickness .25 ]
;  )
end

to-report LJ-pot [r]
  report 4 * eps * ((sigma / r) ^ 12 - (sigma / r) ^ 6)
end
@#$#@#$#@
GRAPHICS-WINDOW
192
10
815
634
-1
-1
15.0
1
10
1
1
1
0
1
1
1
-20
20
-20
20
1
1
1
ticks
30.0

BUTTON
10
379
96
412
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
106
379
191
412
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
0

CHOOSER
25
13
163
58
force-mode
force-mode
"Shear" "Tension"
1

SLIDER
14
249
186
282
system-temp
system-temp
0
.75
0.0
.01
1
NIL
HORIZONTAL

SLIDER
14
292
186
325
f-app
f-app
0
12
0.0
.1
1
N
HORIZONTAL

SLIDER
14
335
186
368
f-app-vert
f-app-vert
0
8
0.0
.1
1
cN
HORIZONTAL

SWITCH
20
123
179
156
create-dislocation?
create-dislocation?
1
1
-1000

SWITCH
867
38
999
71
update-color?
update-color?
0
1
-1000

CHOOSER
14
66
181
111
crystal-view
crystal-view
"large-atoms" "small-atoms" "hide-atoms"
1

SWITCH
860
79
1019
112
diagonal-right-links
diagonal-right-links
0
1
-1000

SWITCH
863
120
1015
153
diagonal-left-links
diagonal-left-links
1
1
-1000

SWITCH
871
161
1009
194
horizontal-links
horizontal-links
1
1
-1000

SLIDER
14
164
186
197
atoms-per-row
atoms-per-row
5
30
22.0
1
1
NIL
HORIZONTAL

SLIDER
14
206
186
239
atoms-per-column
atoms-per-column
5
30
22.0
1
1
NIL
HORIZONTAL

PLOT
876
219
1076
369
KE + PE
NIL
NIL
0.0
200.0
-106.535
-106.51
false
false
"" ""
PENS
"default" 0.01 0 -16777216 true "" ";plot sum [0.5 * (vx ^ 2 + vy ^ 2)] of atoms with [not (posi = \"ll\" or posi = \"lr\")] + sum [PotE] of atoms "
"pen-1" 0.01 0 -2674135 true "" ";plot sum [0.5 * (vx ^ 2 + vy ^ 2)] of atoms with [not (posi = \"ll\" or posi = \"lr\")] + sum [abs(PotE)] of atoms "
"pen-2" 0.01 0 -7500403 true "" "plot sum [0.5 * (vx ^ 2 + vy ^ 2)] of atoms + sum [PotE] of atoms "
"pen-3" 0.01 0 -13840069 true "" ";plot sum [0.5 * (vx ^ 2 + vy ^ 2)] of atoms + sum [abs(PotE)] of atoms "

PLOT
881
413
1081
563
ke
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 0.1 0 -16777216 true "" "plot sum [0.5 * (vx ^ 2 + vy ^ 2)] of atoms "
"pen-1" 1.0 0 -7500403 true "" "plot sum [0.5 * (vx ^ 2 + vy ^ 2)] of atoms with [ posi = \"ll\" or posi = \"lr\"]"
"pen-2" 1.0 0 -2674135 true "" "plot sum [0.5 * (vx ^ 2 + vy ^ 2)] of atoms with [not (posi = \"ll\" or posi = \"lr\")]"

PLOT
1158
407
1358
557
pe
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 0.1 0 -16777216 true "" "plot sum [PotE] of atoms"

MONITOR
52
425
154
470
max-v
[ sqrt( vx ^ 2 + vy ^ 2 )] of max-one-of atoms [ sqrt( vx ^ 2 + vy ^ 2 ) ]
6
1
11

@#$#@#$#@
## WHAT IS IT?

This model displays the common natural phenomenon expressed by the Coulomb's inverse-square law.  It shows what happens when the strength of the force between two charges varies inversely with the square of the distance between them.

## HOW IT WORKS

In this model the formula used to guide each charge's behavior is the standard formula for Coulomb's law:

F = (q1 * q2 * Permittivity) / (r^2)

In this formula:
- "F" is the force between the two charges q1 and q2.
- "Permittivity", the constant of proportionality here, is a property of the medium in which the two charges q1 and q2 are situated.
- "r" is the distance between the centers of the two charges.

This is a single force two body model, where we have a charge q1 (the particle that is created when you press SETUP) and a proton (q2) (the blue particle that appears when you press the mouse button in the view).  If a particle is positively charged, it is colored blue. If it's negatively charged, it will be orange. The force is entirely one-way: only q1 is attracted towards (or repelled from) the proton (q2), while the proton (q2) remains unaffected.  Note that this is purely for purposes of simulation.  In the real world, Coulomb's force acts on all bodies around it.

Gravity is another example of an inverse square force.  Roughly speaking, our solar system resembles a nucleus (sun) with electrons (planets) orbiting around it.

For certain values of q1 (which you can control by using the CHARGE slider), you can watch q1 form elliptic orbits around the mouse pointer (q2), or watch q1 slingshot around q2, similar to how a comet streaks past our sun. The charges q1 and q2 are always set equal in magnitude to each other, although they can differ in their sign.

## HOW TO USE IT

When you press the SETUP button, the charge q1 is created in a medium determined by the permittivity value from the PERMITTIVITY slider. When you click and hold down the mouse anywhere within the view, the model creates a unit of positive charge (q2) at the position of the mouse.

The CHARGE slider sets the value of the charge on q1.  First, select the value of CHARGE on q1. You will see that the color of q1 reflects its charge. (For simulation ease, value of the charge on q2 is set to be the absolute value of this charge. Thus, it also determines at what distances the particles can safely orbit before they get sucked in by an overwhelming force.)

The FADE-RATE slider controls how fast the paths marked by the particles fade.  At 100% there won't be any paths as they fade immediately, and at 0% the paths won't fade at all.

The PERMITTIVITY slider allows you to change values of the constant of proportionality in Coulomb's law. What does this variable manipulate? The charges or the medium in which the charges are immersed?

When the sliders have been set to desirable levels, press the GO button to begin the simulation.  Move the mouse to where you wish q2 to begin, and click and hold the mouse button. This will start the particles moving. If you wish to stop the simulation (say, to change the value of CHARGE), release the mouse button and the particles will stop moving. You may then change any settings you wish. Then, to continue the simulation, simply put your mouse in the window again and click and hold. Objects in the window will only move while the mouse button is pressed down within the window.

## THINGS TO NOTICE

The most important thing to observe is the behavior of q1, the particle first placed in the world at SETUP.

What is the initial velocity for q1?

What happens as you change the value of q1 from negative to positive?

As you run the model, watch the graphs on the right hand side of the world. What can you infer from the graphs about the relationship between potential energy and distance between charges? What can you say about the relationship between Coulomb's force and distance between the charges from the graphs?

Move the mouse around and watch what happens if you move it quickly or slowly. Jiggle it around in a single place, or let it sit still. Observe what patterns the particles fall into. (You may keep FADE-RATE low to watch this explicitly.)

## THINGS TO TRY

Run the simulation playing with different values of:
a) charge - make sure to watch how different values of the CHARGE slider impact the model for any fixed value of permittivity.
b) permittivity - make sure to watch how different values of the PERMITTIVITY slider impact the model for any fixed value of charge.

Can you make q1 revolve around q2?  Imagine, if q1 would be an electron and q2 a proton, then you have just built a hydrogen atom...

As the simulation progresses, you can take data on how
a) Force between the two charges varies with distance between charges;
b) Potential energy changes with distance between charges;
c) Force depends on permittivity.

In each case, take 8 to 10 data points.  Plot your results by hand or by any plotting program.

## EXTENDING THE MODEL

Assign a fixed position to the proton (q1), i.e., make it independent of the mouse position. Assign a variable to its magnitude.

Now create another charge of the breed "centers", and assign a fixed position to it in the graphics window.  Run the model for different positions, magnitude and signs (i.e., "+"ve or "-"ve) of the new "center".

Create many test-charges.  Then place the two "centers", of opposite signs and comparable magnitudes, near the two horizontal edges of the world.  Now run the model.

## RELATED MODELS

* Gravitation

## NETLOGO FEATURES

When a particle moves off of the edge of the world, it doesn't re-appear by wrapping onto the other side (as in most other NetLogo models). The model stops when the particle exits the world.

## CREDITS AND REFERENCES

This model is a part of the NIELS curriculum. The NIELS curriculum has been and is currently under development at Northwestern's Center for Connected Learning and Computer-Based Modeling and the Mind, Matter and Media Lab at Vanderbilt University. For more information about the NIELS curriculum please refer to http://ccl.northwestern.edu/NIELS/.

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Sengupta, P. and Wilensky, U. (2005).  NetLogo Electrostatics model.  http://ccl.northwestern.edu/netlogo/models/Electrostatics.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

To cite the NIELS curriculum as a whole, please use:

* Sengupta, P. and Wilensky, U. (2008). NetLogo NIELS curriculum. http://ccl.northwestern.edu/NIELS/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 2005 Pratim Sengupta and Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

To use this model for academic or commercial research, please contact Pratim Sengupta at <pratim.sengupta@vanderbilt.edu> or Uri Wilensky at <uri@northwestern.edu> for a mutual agreement prior to usage.

<!-- 2005 NIELS Cite: Sengupta, P. -->
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

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
need-to-manually-make-preview-for-this-model
@#$#@#$#@
@#$#@#$#@
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
