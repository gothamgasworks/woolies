import "dart:async";
import "dart:html";
import "dart:convert";
import "dart:typed_data";
import "package:crc32/crc32.dart";

class ZipStoreBuilder {
  ZipStoreBuilder(this._sink);

  void addFile(String name, List<int> bytes, [DateTime lastModificationTime]) {
    _InternalFile file = new _InternalFile(name, bytes, _bytesWritten);
    _files.add(file);
    file.writeLocalFileHeader(_write);
    file.writeContents(_write);
  }

  void finish() {
    int cdrStart = _bytesWritten;
    for (_InternalFile file in _files) file.writeCentralDirectoryFileHeader(_write);
    int recordsEnd = _bytesWritten;
    // end of central directory signature
    _write([0x50, 0x4b, 0x05, 0x06]);
    // disk number and another disk number
    _write([0x00, 0x00, 0x00, 0x00]);
    // number of CDRs on this disk
    _write(_leShort(_files.length));
    // overall number of CDRs
    _write(_leShort(_files.length));
    _write(_leLong(recordsEnd - cdrStart));
    _write(_leLong(cdrStart));
    // comment length
    _write([0x00, 0x00]);
  }

  void _write(List<int> bytes) {
    _sink.add(bytes);
    _bytesWritten += bytes.length;
  }

  int _bytesWritten = 0;
  List<_InternalFile> _files = [];
  StreamSink<List<int>> _sink;
}

List<int> _leShort(int val) => [val & 0xff, (val >> 8) & 0xff];

List<int> _leLong(int val) => new List.generate(4, (int b) => (val >> (b << 3)) & 0xff);

class _InternalFile {
  _InternalFile(String name, this._bytes, this._offsetOfHeader, [DateTime mod])
      : _nameBytes = UTF8.encode(name),
        _mod = mod ?? new DateTime.now() {
    if (_nameBytes.length > 0xffff) throw new ArgumentError("File name is too long: $name");
  }

  void writeLocalFileHeader(void add(List<int> event)) {
    // local file header signature
    add([0x50, 0x4b, 0x03, 0x04]);
    // version needed to extract (20 = 0x14)
    add([0x14, 0x00]);
    // general purpose bit flag
    add([0x08, 0x00]);
    // compression method (store = 0)
    add([0x00, 0x00]);
    // last modification time
    _writeModificationTime(add);
    // crc-32
    add([0, 0, 0, 0]);
    // compressed size
    add([0, 0, 0, 0]);
    // uncompressed size
    add([0, 0, 0, 0]);
    // file name length
    add(_leShort(_nameBytes.length));
    // extra field length
    add([0, 0]);
    add(_nameBytes);
  }

  void writeContents(void add(List<int> event)) {
    add(_bytes);
    _crc32 = CRC32.compute(_bytes);
    _compressedLength = _bytes.length;
    _uncompressedLength = _bytes.length;
    add(_leLong(_crc32));
    add(_leLong(_compressedLength));
    add(_leLong(_uncompressedLength));
    _bytes = null;
  }

  void writeCentralDirectoryFileHeader(void add(List<int> event)) {
    // central directory file header signature
    add([0x50, 0x4b, 0x01, 0x02]);
    // version: unix (0x03), 2.3 (0x17 = 23)
    add([0x03, 0x17]);
    // version needed
    add([0x14, 0x00]);
    // general purpose bit flag
    add([0x00, 0x00]);
    // compression method (store = 0)
    add([0x00, 0x00]);
    // last modification time
    _writeModificationTime(add);
    add(_leLong(_crc32));
    add(_leLong(_compressedLength));
    add(_leLong(_uncompressedLength));
    // file name length
    add(_leShort(_nameBytes.length));
    // extra field length
    add([0, 0]);
    // file comment length
    add([0, 0]);
    // disk # start
    add([0, 0]);
    // internal attributes
    add([0, 0]);
    // external attributes
    add([0, 0, 0, 0]);
    add(_leLong(_offsetOfHeader));
    add(_nameBytes);
  }

  void _writeModificationTime(void add(List<int> event)) {
    int time = (_mod.second ~/ 2) | (_mod.minute << 5) | (_mod.hour << 11);
    add(_leShort(time));
    int date = (_mod.day) | (_mod.month << 5) | (_mod.year - 1980 << 9);
    add(_leShort(date));
  }

  DateTime _mod;
  List<int> _nameBytes;
  List<int> _bytes;
  int _uncompressedLength;
  int _compressedLength;
  int _crc32;
  int _offsetOfHeader;
}

class BlobSink extends StreamSink<List<int>> {
  Blob toBlob() {
    Blob blob = new Blob(parts, "application/octet-stream");
    // this sink is now invalid
    parts = null;
    return blob;
  }

  int get currentLength => _size;

  @override
  void add(List<int> event) {
    if (event is! Uint8List) event = new Uint8List.fromList(event);
    parts.add(event);
    _size += event.length;
    _bufferedSize += event.length;
    // flatten the thing if it gets over four megabytes
    if (_bufferedSize > 4 * 1048576) {
      print("Flattening. Size is $_size, buffered: $_bufferedSize");
      Blob blob = toBlob();
      parts = [blob];
      _bufferedSize = 0;
    }
  }

  @override
  void addError(Object error, [StackTrace stackTrace]) {}

  @override
  Future addStream(Stream<List<int>> stream) async {}

  @override
  Future close() async {}

  @override
  Future get done async => null;

  List<dynamic> parts = [];
  int _size = 0;
  int _bufferedSize = 0;
}
