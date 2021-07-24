xquery version "3.1";

import module namespace dicey="http://line-o.de/xq/dicey";

declare namespace svg="http://www.w3.org/2000/svg";

declare function local:rgb ($rng as map(*)) as map(*) {
    let $result := dicey:sequence(3, dicey:ranged-random-integer(0, 255, $rng))
    return map:merge((
        $result?generator,
        map {
            "_dicey": true(),
            "_item": $result?sequence,
            "_next": function () { local:rgb($result?generator?next()) }
        }
    ))
};

declare function local:line ($c, $rng as map(*)) as map(*) {
    let $amt := dicey:ranged-random(1.2, 2, $rng)?_item
    let $a := ($amt, -$amt)[dicey:coinflip($rng)?_index]
    let $functions := [
        function($x) { -$x || " " || -$x + $a },
        function($x) { $x div $a || " " || $a * $x },
        function($x) { -$x div $a + 1 || " " || $a * 0.1 * $x },
        function($x) { $x || " " || -$a * $x }
    (:        ,:)
    (:        function($x) { -$x || " " || 0.05 * $x * $x - $x }:)
    ]

    let $color := dicey:pick-from-array($c, $rng)
    let $fill := $color?_item

    let $randfunc := dicey:pick-from-array($functions, $color?next())

    let $functions := dicey:sequence(6, $randfunc)
    let $seq := $functions?sequence
    let $d := 
        "M " || $seq[1](1) || 
        " c " || $seq[1](2) || "," || $seq[2](7) || "," || $seq[3](12) || 
        " s " || $seq[2](3) || "," || $seq[4](4) || 
        " s " || $seq[3](4) || "," || $seq[5](5) || 
        " s " || $seq[4](2) || "," || $seq[6](6) || 
        " q " || $seq[4](7) || "," || $seq[5](16) ||
        " t " || $seq[6](7) || 
        " t " || $seq[6](8) || 
        " q " || $seq[6](3) || "," || $seq[5](9) ||
        " t " || $seq[6](1) || 
        " t " || $seq[6](2) 
(:        || " Z":)

    return map:merge((
        $functions?generator,
        map {
            "_dicey": true(),
            "_item": <path xmlns="http://www.w3.org/2000/svg" 
                d="{$d}" fill="transparent" opacity=".75" stroke="{$fill}" />,
            "_next": function () { local:line($c, $functions?generator?next()) }
        }
    ))
};


(: set content-type for clients  :)

let $header := response:set-header("Content-Type", "image/svg+xml")

(: set actual contents :)

let $seed := request:get-parameter("seed", dicey:ranged-random-integer(0, 9223372036854775807)?_item)
let $initial-random := random-number-generator($seed)

let $how-many := dicey:d12($initial-random)?_item
let $rgb := local:rgb($initial-random)
let $c := $rgb?_item

let $colors := array {
    ``[rgb(`{string-join($c, ",")}`)]``,
    ``[rgb(`{$c[3]}`, `{$c[2]}`, `{$c[1]}`)]``,
    ``[rgb(`{$c[3]}`, `{$c[1]}`, `{$c[2]}`)]``,
    ``[rgb(`{$c[2]}`, `{$c[1]}`, `{$c[3]}`)]``
}
let $line-generator := local:line($colors, $rgb?next())

return 
<svg viewBox="-100 -100 200 200" xmlns="http://www.w3.org/2000/svg">
  <text x="-100" y="-90" style="font-family: sans-serif; font-size: 4; color: rgb(128,128,128)">{$seed}</text>
  <g>{dicey:sequence($how-many, $line-generator)?sequence}</g>
</svg>
