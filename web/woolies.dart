import "dart:async";
import "dart:html";
import "dart:convert";
import "package:woolies/zip_tools.dart";

class Woolies {
  Woolies(this.numFrames, this.fps, {this.timeOffset = 0, bool wantMillisecs = false})
      : _wantMillisecs = wantMillisecs ?? false {
    timeOffset ??= 0;
    _ctx = _canvas.context2D;

    _refreshMetrics();
  }

  Future<Null> render() {
    if (_rendering) throw new StateError("Rendering is in progress");
    _rendering = true;
    Completer<Null> completer = new Completer();
    int frame = 0;
    int numFrames = this.numFrames;
    if (numFrames <= 0) throw new ArgumentError("Invalid parameters: numFrames is not positive");
    BlobSink sink = new BlobSink();
    ZipStoreBuilder zip = new ZipStoreBuilder(sink);

    IdleRequestCallback _renderNextFrame;

    _renderNextFrame = (IdleDeadline deadline) {
      if (frame < numFrames) {
        int currentFrame = frame;
        _progress = frame / numFrames;
        ++frame;
        drawFrame(frameNumber: currentFrame);
        if (_nextFrame != null && _nextFrameCompleter != null) {
          drawFrame(frameNumber: currentFrame, contextOverride: _nextFrame);
          _nextFrameCompleter.complete();
          _nextFrame = null;
          _nextFrameCompleter = null;
        }

        String base64 = _canvas.toDataUrl("image/png");
        int comma = base64.indexOf(",");
        base64 = base64.substring(comma + 1);

        String filename = "countdown${currentFrame.toString().padLeft(8, '0')}.png";
        zip.addFile(filename, BASE64.decode(base64));
        if ((currentFrame & 127) == 0) print("$filename ${sink.currentLength}");

        window.requestIdleCallback(_renderNextFrame);
      } else {
        zip.finish();
        AnchorElement anchor = new AnchorElement();
        anchor.download = "countdown.zip";
        anchor.href = Url.createObjectUrl(sink.toBlob());
        anchor.click();
        _rendering = false;
        completer.complete();
      }
    };

    _renderNextFrame(null);

    return completer.future;
  }

  Future<Null> peekRendering(CanvasRenderingContext2D target) {
    if (!_rendering) throw new StateError("Rendering is in progress");
    _nextFrameCompleter = new Completer();
    _nextFrame = target;

    return _nextFrameCompleter.future;
  }

  void drawFrame({double timeLeft, int frameNumber = 0, CanvasRenderingContext2D contextOverride}) {
    frameNumber ??= 0;
    timeLeft ??= (numFrames - frameNumber - 1) / fps + timeOffset;
    CanvasRenderingContext2D ctx = contextOverride ?? _ctx;
    if (contextOverride != null) _setupStyles(contextOverride);
    String text = _formatTime(timeLeft);

    ctx.clearRect(0, 0, ctx.canvas.width, ctx.canvas.height);

    ctx.strokeText(text, x, y);
    ctx.fillText(text, x, y);
  }

  void resize({int newWidth, int newHeight}) {
    if (newWidth == null && newHeight == null) return;
    if (newWidth != null) _canvas.width = newWidth;
    if (newHeight != null) _canvas.height = newHeight;
    _refreshMetrics();
  }

  bool get isRendering => _rendering;

  double get progress => _progress;

  int get width => _canvas.width;

  set width(int newWidth) => resize(newWidth: newWidth);

  int get height => _canvas.height;

  set height(int newHeight) => resize(newHeight: newHeight);

  bool get wantMillisecs => _wantMillisecs;

  set wantMillisecs(bool value) {
    if (value != _wantMillisecs) {
      _wantMillisecs = value;
      _refreshMetrics();
    }
  }

  String _formatTime(num time) {
    int elapsed = time.floor();
    String minutes = (elapsed ~/ 60).toString().padLeft(2, "0");
    String seconds = (elapsed % 60).toString().padLeft(2, "0");
    String ms = (time.remainder(1.0) * 1000).floor().toString().padLeft(3, "0");

    if (_wantMillisecs)
      return "$minutes:$seconds.$ms";
    else
      return "$minutes:$seconds";
  }

  void _refreshMetrics({CanvasRenderingContext2D contextOverride, String text}) {
    CanvasRenderingContext2D ctx = contextOverride ?? _ctx;
    _setupStyles(ctx);
    text ??= _formatTime(0);
    TextMetrics metrics = ctx.measureText(text);

    x = (ctx.canvas.width - metrics.width) * 0.5;
    y = ctx.canvas.height * 0.75;
  }

  void _setupStyles([CanvasRenderingContext2D ctx]) {
    ctx ??= _ctx;
    ctx.font = "72px 'Helvetica Neue'";

    ctx.fillStyle = "white";
    ctx.strokeStyle = "black";
    ctx.lineWidth = 4;
  }

  int numFrames;
  num fps;
  num timeOffset;
  bool _wantMillisecs;
  num x;
  num y;
  bool _rendering = false;
  double _progress;
  CanvasRenderingContext2D _nextFrame;
  Completer<Null> _nextFrameCompleter;
  CanvasRenderingContext2D _ctx;
  CanvasElement _canvas = new CanvasElement()
    ..width = 1280
    ..height = 120;

  static final List<Property<Woolies>> properties = new List.unmodifiable([
    new Property<Woolies>("width", (Woolies w) => w.width.toString(),
        (Woolies w, String value) => w.width = int.parse(value)),
    new Property<Woolies>("height", (Woolies w) => w.height.toString(),
        (Woolies w, String value) => w.height = int.parse(value)),
    new Property<Woolies>("numFrames", (Woolies w) => w.numFrames.toString(),
        (Woolies w, String value) => w.numFrames = int.parse(value)),
    new Property<Woolies>("fps", (Woolies w) => w.fps.toString(),
        (Woolies w, String value) => w.fps = double.parse(value)),
    new Property<Woolies>("timeOffset", (Woolies w) => w.timeOffset.toString(),
        (Woolies w, String value) => w.timeOffset = double.parse(value)),
    new Property<Woolies>("wantMillisecs", (Woolies w) => w.wantMillisecs.toString(),
        (Woolies w, String value) => w.wantMillisecs = value == true.toString()),
  ]);
}

typedef String Getter<T>(T obj);
typedef void Setter<T>(T obj, String value);

class Property<T> {
  const Property(this.name, this.getter, this.setter);

  final String name;
  final Getter<T> getter;
  final Setter<T> setter;
}

final Map<String, bool> stringToBool =
    new Map.unmodifiable(new Map.fromIterable([false, true], key: (val) => val.toString()));

void _refreshFields(Woolies woolies) {
  for (Property<Woolies> p in Woolies.properties) {
    InputElement input = document.getElementById(p.name);
    if (input.type == "checkbox")
      input.checked = stringToBool[p.getter(woolies)];
    else
      input.value = p.getter(woolies);
  }
}

void _applyFields(Woolies woolies) {
  if (woolies.isRendering) return;
  for (Property<Woolies> p in Woolies.properties) {
    InputElement input = document.getElementById(p.name);
    String value = input.type == "checkbox" ? input.checked.toString() : input.value;
    p.setter(woolies, value);
  }
}

Future<Null> startRendering(Woolies woolies) async {
  if (woolies.isRendering) return;
  _applyFields(woolies);
  _refreshFields(woolies);
  CanvasElement preview = document.getElementById("preview");
  preview.width = woolies.width;
  preview.height = woolies.height;
  String save = document.title;
  document.title = "Rendering\u2026";
  woolies.render().then((_) => document.title = save);
  ProgressElement progress = document.getElementById("progress");
  progress.max = 1000;
  progress.style.visibility = "visible";
  int counter = 0;
  while (woolies.isRendering) {
    if ((counter & 15) == 0) woolies.peekRendering(preview.context2D);
    progress.value = 1000.0 * woolies.progress;
    await new Future.delayed(new Duration(seconds: 1));
    ++counter;
  }
  progress.style.visibility = "hidden";
}

Future main() async {
  Woolies woolies = new Woolies(100, 30);
  _refreshFields(woolies);
  document.getElementById("generateButton").onClick.listen((_) {
    startRendering(woolies);
  });
  document.getElementById("previewButton").onClick.listen((_) {
    if (woolies.isRendering) return;
    _applyFields(woolies);
    _refreshFields(woolies);
    CanvasElement preview = document.getElementById("preview");
    preview.width = woolies.width;
    preview.height = woolies.height;
    woolies.drawFrame(timeLeft: 754.567, contextOverride: preview.context2D);
  });
}
