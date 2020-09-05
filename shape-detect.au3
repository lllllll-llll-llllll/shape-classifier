#include <array.au3>
#include <file.au3>
#include <math.au3>

   const $filename = 'input.png'
   const $area_min = 1000		; maybe this could be dynamically set based on input image dimensions
   const $area_max = 80000		; ^

   $command = 'magick '& $filename & ' -negate -connected-components 4 -auto-level -depth 8 -sepia-tone 50% -define connected-components:verbose=true -connected-components 4 -auto-level -depth 8 -sepia-tone 50% islands.png > islands.txt'
   runwait(@ComSpec & " /c " & $command, "", @SW_HIDE)

   ;$command = 'magick islands.png -negate -define connected-components:verbose=true -connected-components 4 -auto-level -depth 8 islands2.png > islands2.txt'
   ;runwait(@ComSpec & " /c " & $command, "", @SW_HIDE)

   $islands = FileReadToArray('islands.txt')
   for $j = 2 to ubound($islands) - 1
	  local $x_points[0]
	  local $y_points[0]
	  $split = stringsplit($islands[$j], ' ', 2)
	  $area  = $split[5]
	  $colors = stringtrimleft($split[6], 1)
	  $colors = stringreplace($colors, '%', '%%')
	  if ($area > $area_min) and ($area < $area_max) then
		 ; [] [] [0:] [618x395+0+0] [306.1,198.4] [212077] [srgb(10.4182%,0.828823%,6.20975e-07%)]
		 $geometry = $split[3]
		 $split = stringsplit($split[3], 'x+', 2)
		 $x = $split[0]
		 $y = $split[1]
		 $x_offset = $split[2]
		 $y_offset = $split[3]
		 $x_center = int($x / 2)
		 $y_center = int($y / 2)

			;color data for the target object --> $color[r, g, b]
			$colors = StringReplace($colors, '%', '')
			$split = stringsplit($colors, '()', 2)
			$colors = $split[1]
			$split = stringsplit($colors, ',', 2)
			$red   = round(255 * number($split[0]) / 100)
			$green = round(255 * number($split[1]) / 100)
			$blue  = round(255 * number($split[2]) / 100)
			$colors = 'rgb(' & $red & ',' & $green & ',' & $blue & ')'

		 ;GOOD
		 $command = 'magick islands.png -crop ' & $geometry & ' +append -bordercolor black -border 2x2 -fill black +opaque ' & $colors & ' -fill white -opaque ' & $colors & ' -canny 1x1+50%+90% -threshold 50% -type bilevel pixels.txt'
		 runwait(@ComSpec & " /c " & $command, "", @SW_HIDE)

		 ;$command = 'magick islands.png -crop ' & $geometry & ' +append -bordercolor black -border 2x2 -fill black +opaque ' & $colors & ' -fill white -opaque ' & $colors & ' -canny 1x1+50%+90% TEST.png'
		 ;runwait(@ComSpec & " /c " & $command, "", @SW_HIDE)
		 ;$command = 'magick TEST.png -threshold 50% -type bilevel TESTPIXELS.txt'
		 ;runwait(@ComSpec & " /c " & $command, "", @SW_HIDE)

		 ;there are too many pixels in pixels.txt. i don't think an edge is ebing output correctly, i think the entire shape is.
		 ;i think i was mistaken

		 ;magick isolated1.png -fill black +opaque rgb(99.1157%,99.1157%,63.3966%) isolated2.png

		 #cs
			;convert bounding box of object into a bunch of lines drawing the object boundaries. it is messy
			$command = 'magick ' & $filename & ' -crop ' & $geometry & ' +append -bordercolor black -border 2x2 -canny 1x1+50%+90% -crop ' & $x+1 & 'x' & $y+1 & '+' & $x_offset+1 & '+' & $y_offset+1 & ' edges.png'
			runwait(@ComSpec & " /c " & $command, "", @SW_HIDE)
			;msgbox(1,'paused', 'just made edges.png')

			;generate a mask of the object
			 $command = 'magick cutout.png -fill white -draw "color ' & $x_center & ',' & $y_center & ' floodfill" -fill red -draw "color ' & $x_center & ',' & $y_center & ' floodfill" -fill black -opaque white -fill white -opaque red mask.png'
			 runwait(@ComSpec & " /c " & $command, "", @SW_HIDE)
			; msgbox(1,'paused', 'just made mask.png')

			$command = 'magick edges.png -fill white -draw "color ' & $x_center & ',' & $y_center & ' floodfill" mask1.png' ;disabled
			runwait(@ComSpec & " /c " & $command, "", @SW_HIDE)
			;msgbox(1,'paused', 'just made mask1.png')

			$command = 'magick mask1.png -fill red -draw "color ' & $x_center & ',' & $y_center & ' floodfill" mask2.png' ;disabled
			runwait(@ComSpec & " /c " & $command, "", @SW_HIDE)
			;msgbox(1,'paused', 'just made mask2.png')

			$command = 'magick mask2.png -fill black -opaque white mask3.png' ;disabled
			runwait(@ComSpec & " /c " & $command, "", @SW_HIDE)
			;msgbox(1,'paused', 'just made mask3.png')

			$command = 'magick mask3.png -fill white -opaque red mask4.png' ;disabled
			runwait(@ComSpec & " /c " & $command, "", @SW_HIDE)
			;msgbox(1,'paused', 'just made mask4.png')

			;apply mask edges to produce a clean edge
			$command = 'composite -compose multiply mask4.png edges.png edges.png'	;disabled
			runwait(@ComSpec & " /c " & $command, "", @SW_HIDE)
			;msgbox(1,'paused', 'just made clean edges.png')

			;get the edge points
			;$command = 'convert edges.png -threshold 50% -type bilevel pixels.txt'
			runwait(@ComSpec & " /c " & $command, "", @SW_HIDE)
			;msgbox(1,'paused', 'just made pixels.txt')
		 #ce

		 ;make arrays for the x and y positions for all white edge pixels
		 $pixels = FileReadToArray('pixels.txt')
		 for $k = 1 to ubound($pixels) - 1
			if StringInStr($pixels[$k], 'FF') then
			   $split = stringsplit($pixels[$k], ',:', 2)
			   _arrayadd($x_points, $split[0])
			   _arrayadd($y_points, $split[1])
			endif
		 next

		 ;construct waveform
		 local $dists[360]
		 for $k = 0 to ubound($x_points) - 1
			$x1 = $x_points[$k]
			$y1 = $y_points[$k]
			$x2 = $x_center
			$y2 = $y_center

			$angle  = int(_degree(angle($x1, $y1, $x2, $y2)))
			$distance = int(distance($x1, $x2, $y1, $y2))
			if $distance > $dists[$angle] then $dists[$angle] = $distance

		 next

		 ;fill in gaps of the waveform
		 $max = 0
		 $min = 9999
		 $gaps = true
		 while $gaps
			$gaps = false
			for $k = 0 to 359
			   if $dists[$k] > $max then $max = $dists[$k]

			   if $dists[$k] = '' then
				  $pre1 = mod($k - 1, 360)
				  $pre2 = mod($k - 2, 360)
				  if $pre1 < 0 Then $pre1 += 360
				  if $pre2 < 0 Then $pre2 += 360
				  $pre1 = $dists[$pre1]
				  $pre2 = $dists[$pre2]
				  if $pre2 = '' or $pre1 = '' then $gaps = true

				  $dists[$k] = ($pre1 - $pre2) + $pre2
			   else
				  if $dists[$k] < $min then $min = $dists[$k]
			   endif

			next
		 wend

		 ;convert waveform into an array of strings of lines for imagemagick to draw
		 #cs
			local $waveform[360]
			for $k = 0  to 359
			   $waveform[$k] = 'line ' & $k &','& 0 &' '& $k &','& $dists[$k]
			next
			$lines = FileOpen('lines.txt', 10)
			FileWrite($lines, '')
			_FileWriteFromArray($lines, $waveform)
			FileClose($lines)

			;draw and output the waveform
			;$command = 'magick -size 360x300 xc:white -stroke black -draw @lines.txt waveform' & $j & '.png'
			;runwait(@ComSpec & " /c " & $command, "", @SW_HIDE)
		 #ce


		 ; construct barcode
		 $dif = $min / $max
		 local $barcode[360]
		 for $k = 0 to 359
			;if $dists[$k] > $max / 2 then
			;if $dists[$k] > $max * 0.7 then
			if $dists[$k]  > (($max - $min) / 2) + $min then
			;if $dists[$k] > ((($max - $min) / 2) + $min * (1 - $dif / 2) )  then
			   $barcode[$k] = 1
			else
			   $barcode[$k] = 0
			endif
		 next


		 ;convert barcode into an array of strings of lines for imagemagick to draw
		 #cs
			local $barcode_text[360]
			for $k = 0  to 359
			   $barcode_text[$k] = 'line ' & $k &','& 0 &' '& $k &','& $barcode[$k] * 300
			next
			$bars = FileOpen('barcode.txt', 10)
			FileWrite($bars, '')
			_FileWriteFromArray($bars, $barcode_text)
			FileClose($bars)

			;draw and output the barcode
			$command = 'magick -size 360x300 xc:white -stroke black -draw @barcode.txt barcode' & $j & '.png'
			runwait(@ComSpec & " /c " & $command, "", @SW_HIDE)

		 #ce


		 ;PRODUCE TRAINING DATA
		 #cs
			$dataset = fileopen(@scriptdir & '\data\moons.txt', 9)
			$interim = $barcode
			for $k = 1 to 358
			   $a_start = _ArrayExtract($barcode, 0, $k)
			   $a_end   = _ArrayExtract($barcode, $k + 1, 359)
			   $text    = _ArrayToString($a_end, '') & _ArrayToString($a_start, '')
			   FileWrite($dataset, $text & @CRLF)

			next
		 #ce

		 ;COMPARE TO DATASETS
		 ;#cs
			$best = 0
			local $tally[6] = [0, 0, 0, 0, 0, 0]
			local $datasets[6] = ['circles.txt', 'hearts.txt', 'triangles.txt', 'squares.txt', 'rectangles.txt', 'moons.txt']
			for $s = 0 to ubound($datasets) - 1
			   $set = FileReadToArray(@scriptdir & '\data\' & $datasets[$s])

			   ;iterate through each line
			   for $l = 0 to ubound($set) - 1
				  $line = stringsplit($set[$l], '', 2)
				  ;_arraydisplay($line, 'line')

				  $same = 0
				  ;iterate through each char
				  for $c = 0 to ubound($line) - 1
					 ;msgbox(1, '', 'this:' & $dists[$c] & '  char:' &  $line[$c])
					 if $barcode[$c] = $line[$c] then
						$same += 1
					 endif
				  next

				  if $same > 300 then $tally[$s] += 1
			   next

			   ;determine which set has been closest at the end of every dataset
			   if $s = 0 then
				  $best = $s
			   elseif $tally[$s] > $tally[$s - 1] then
				  $best = $s
			   endif
			next

		 $s_total   = $tally[0] + $tally[1] + $tally[2] + $tally[3] + $tally[4] + $tally[5]
		 $s_percent = int(($tally[$best] / $s_total) * 100) &  '%'


		 ;msgbox(1,'best is', $datasets[$best])
		 msgbox(1, $datasets[$best], 'confidence:' & $s_percent)
		 _arraydisplay($tally, 'similarity counts')
		 ;#ce


		; msgbox(1,'paused',$j)


	  endif
   next





; the classification process can perhaps be improved by looking toward the game of 20q for inspiration
; instead of looking at everything, you look at only 2 things, then depending on which is more accurate, look into 2 sub-things of that thing
; to start with, we can first measure the ratio of peaks to determine roundness
; if it is mostly round, we can search through round-shapes, like pentagon, hexagon, octagon, moons?
; if it isn't very round, we can compare rectangles, squares, stars

; the question is how to determine the roundness of an object.









func distance($d1, $d2, $d3, $d4)
   $a = Abs($d1 - $d2)
   $b = Abs($d3 - $d4)
   return Sqrt(($a * $a) + ($b * $b))
endfunc

;taken from Luigi's math UDF - https://www.autoitscript.com/forum/topic/177413-position-to-anglesdegrees/
func angle($iX1 = 0, $iY1 = 0, $iX2 = 0, $iY2 = 0)
   const $pi = 3.141592653589793
   const $pi2 = $pi / 2
   const $2pi = $pi * 2
   const $5pi = $pi * 1.5

   if $iX1 = $iX2 then
	  if $iY1 > $iY2 then
		 return $pi / 2
	  else
		 return $5pi
	  endif
   else
      $__iDX = $iX2 - $iX1
      $__iDY = $iY2 - $iY1
      if $iX1 > $iX2 then
         if $iY1 = $iY2 then
            return $pi
         else
            if $iY1 > $iY2 then
               return $pi2 + ATan($__iDX / $__iDY)
            else
               return $5pi + ATan($__iDX / $__iDY)
            endif
         endif
	  else
         if $iY1 = $iY2 then
            return 0
         else
            if $iY1 > $iY2 then
               return $pi2 + ATan($__iDX / $__iDY)
            else
               return $5pi + ATan($__iDX / $__iDY)
            endif
         endif
      endif
   endif
endfunc



















