# Platform-channel contract
All methods use the exact prefix `com.smartvisionband/`.
Events are separate EventChannels with `/events` appended; a MethodChannel and an
EventChannel cannot share one messenger name safely because they install handlers.

| Module | Methods | Events |
|---|---|---|
| camera | start, stop, configure({confidence}) | camera/events |
| bluetooth | bonded, connect({address}), send({line}), disconnect | bluetooth/events |
| audio | isBluetoothOutput, vibrate | none |
| service | start, stop | none |

Camera ready event: `{type: state, ready: true}` only after USB grant, stream and
model init succeed. Detection: `{timestamp: epochMs, latencyMs: number, fps: number,
detections: [{class: string, confidence: number, bbox: [x1,y1,x2,y2], centerX: number}]}`.
Boxes are normalized to original-frame coordinates. No frames cross into Dart.
Bluetooth event: `{type: state, connected: bool}` or `{type: rx|tx, line: string}`
or `{type: error, message: string}`. Ready and connection events are not assumptions.

Handlers are registered explicitly in MainActivity. Dart guards translate missing
plugins to visible errors; this does not prove MissingPluginException is impossible.
All event errors must be handled. Do not call channels before Flutter binding init.
