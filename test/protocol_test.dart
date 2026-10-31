import 'package:flutter_test/flutter_test.dart';
import 'package:smart_vision_band/models/distance_event.dart';
void main(){
 test('DIST and BATT parser',(){expect(Protocol.parse('DIST:35\r\n')?.value,35);expect(Protocol.parse('BATT:99')?.value,99);});
 test('reject invalid ranges and values',(){for(final s in ['DIST:0','DIST:-1','DIST:NaN','DIST:Infinity','DIST:601','BATT:101','DIST:','PONG','DIST:3:5']){expect(Protocol.parse(s),isNull,reason:s);}});
}
