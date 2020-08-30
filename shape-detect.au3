#include <array.au3>
#include <file.au3>
#include <math.au3>

   const $filename = '1.png'
   const $area_min = 500		; maybe this could be dynamically set based on input image dimensions
   const $area_max = 80000		; ^

   $command = 'magick 1.png -negate -define connected-components:verbose=true -connected-components 4 -auto-level -depth 8 islands.png > islands.txt'
   runwait(@ComSpec & " /c " & $command, "", @SW_HIDE)

   $islands = FileReadToArray('islands.txt')
   for $j = 1 to ubound($islands) - 1
	  local $x_points[0]
	  local $y_points[0]
	  $split = stringsplit($islands[$j], ' ', 2)
	  $area  = $split[5]
	  if ($area > $area_min) and ($area < $area_max) then
		 $geometry = $split[3]
		 $split = stringsplit($split[3], 'x+', 2)
		 $x = $split[0]
		 $y = $split[1]
		 $x_offset = $split[2]
		 $y_offset = $split[3]
		 $x_center = int($x / 2)
		 $y_center = int($y / 2)

		 $command = 'magick ' & $filename & ' -crop ' & $geometry & ' shape' & $j & '.png'
		 runwait(@ComSpec & " /c " & $command, "", @SW_HIDE)

		 ;convert bounding box of object into a bunch of lines drawing the object boundaries. it is messy
		 $command = 'magick ' & $filename & ' -crop ' & $geometry & ' +append -bordercolor black -border 2x2 -canny 1x1+50%+90% -crop ' & $x+1 & 'x' & $y+1 & '+' & $x_offset+1 & '+' & $y_offset+1 & ' edges.png'
		 runwait(@ComSpec & " /c " & $command, "", @SW_HIDE)
		 ;msgbox(1,'paused', 'just made edges.png')

		 ;generate a mask of the object
		 ; $command = 'magick cutout.png -fill white -draw "color ' & $x_center & ',' & $y_center & ' floodfill" -fill red -draw "color ' & $x_center & ',' & $y_center & ' floodfill" -fill black -opaque white -fill white -opaque red mask.png'
		 ; runwait(@ComSpec & " /c " & $command, "", @SW_HIDE)
		 ; msgbox(1,'paused', 'just made mask.png')

		 $command = 'magick edges.png -fill white -draw "color ' & $x_center & ',' & $y_center & ' floodfill" mask1.png'
		 runwait(@ComSpec & " /c " & $command, "", @SW_HIDE)
		 ;msgbox(1,'paused', 'just made mask1.png')

		 $command = 'magick mask1.png -fill red -draw "color ' & $x_center & ',' & $y_center & ' floodfill" mask2.png'
		 runwait(@ComSpec & " /c " & $command, "", @SW_HIDE)
		 ;msgbox(1,'paused', 'just made mask2.png')

		 $command = 'magick mask2.png -fill black -opaque white mask3.png'
		 runwait(@ComSpec & " /c " & $command, "", @SW_HIDE)
		 ;msgbox(1,'paused', 'just made mask3.png')

		 $command = 'magick mask3.png -fill white -opaque red mask4.png'
		 runwait(@ComSpec & " /c " & $command, "", @SW_HIDE)
		 ;msgbox(1,'paused', 'just made mask4.png')


		 ;apply mask edges to produce a clean edge
		 $command = 'composite -compose multiply mask4.png edges.png edges.png'
		 runwait(@ComSpec & " /c " & $command, "", @SW_HIDE)
		 ;msgbox(1,'paused', 'just made clean edges.png')

		 ;get the edge points
		 $command = 'convert edges.png -threshold 50% -type bilevel pixels.txt'
		 runwait(@ComSpec & " /c " & $command, "", @SW_HIDE)
		 ;msgbox(1,'paused', 'just made pixels.txt')

		 ;make array for the x and y positions for all white edge pixels
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
		 local $waveform[360]
		 for $k = 0  to 359
			$waveform[$k] = 'line ' & $k &','& 0 &' '& $k &','& $dists[$k]
		 next
		 $lines = FileOpen('lines.txt', 10)
		 FileWrite($lines, '')
		 _FileWriteFromArray($lines, $waveform)
		 FileClose($lines)

		 ;draw and output the waveform
		 $command = 'magick -size 360x300 xc:white -stroke black -draw @lines.txt waveform' & $j & '.png'
		 runwait(@ComSpec & " /c " & $command, "", @SW_HIDE)
		 ;msgbox(1,'paused', 'just made waveform')



		 ; construct barcode
		 $dif = $min / $max
		 local $barcode[360]
		 for $k = 0 to 359
			;if $dists[$k] > $max / 2 then
			;if $dists[$k] > $max * 0.7 then
			;msgbox(1,'', (($max - $min) / 2) + $min)
			if $dists[$k]  > (($max - $min) / 2) + $min then
			;if $dists[$k] > ((($max - $min) / 2) + $min * (1 - $dif / 2) )  then
			   $barcode[$k] = 1
			else
			   $barcode[$k] = 0
			endif
		 next

		 ;convert barcode into an array of strings of lines for imagemagick to draw
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
		 clipput($command)
		 runwait(@ComSpec & " /c " & $command, "", @SW_HIDE)
		 ;msgbox(1,'paused', $j & ' difference: ' & $dif)






	  endif
   next





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



















