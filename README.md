# woolies

Generates countdown timer frames which can be overlaid on movies using `ffmpeg`.

Usage:

1. Figure out how many frames the movie has and what the
   frame rate is and what the dimensions of the frames are
   (you can use `ffprobe` or `ffmpeg` for this).
2. Enter the data: the main idea is that height is much smaller
   than the video frame height.
3. Generate the frames. They'll be downloaded in a zip file.
4. Unzip the countdown frames in a directory of your choosing.
5. Overlay the countdown on your video: ```bash
$ ffmpeg -i movie.mp4 -r <frame rate> -f image2 -i 'countdown/frame%08d.png' -filter_complex "[0:v][1:v] overlay=0:0" -pix_fmt yuv420p -c:a copy -preset medium -c:v libx264 movie_with_countdown.mp4
```
