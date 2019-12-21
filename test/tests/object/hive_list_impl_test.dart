import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:hive/src/hive_impl.dart';
import 'package:hive/src/object/hive_list_impl.dart';
import 'package:hive/src/object/hive_object.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import '../common.dart';
import '../mocks.dart';

HiveObject _getHiveObject(String key, BoxMock box) {
  var hiveObject = TestHiveObject();
  hiveObject.init(key, box);
  when(box.get(key, defaultValue: argThat(isNotNull, named: 'defaultValue')))
      .thenReturn(hiveObject);
  when(box.get(key)).thenReturn(hiveObject);
  return hiveObject;
}

void main() {
  group('HiveListImpl', () {
    group('HiveListImpl()', () {
      test('throws exception if given HiveObject is in no box or a LazyBox',
          () {
        var objInNoBox = TestHiveObject();
        expect(
          () => HiveListImpl(objInNoBox, BoxMock()),
          throwsHiveError('needs to be in a non-lazy box'),
        );

        var objInLazyBox = TestHiveObject();
        objInLazyBox.init('key', LazyBoxMock());
        expect(
          () => HiveListImpl(objInNoBox, BoxMock()),
          throwsHiveError('needs to be in a non-lazy box'),
        );
      });

      test('links HiveList to HiveObject', () {
        var box = BoxMock();
        var obj = _getHiveObject('key', box);

        var list = HiveListImpl(obj, box);

        expect(obj.debughiveLists, [list]);
      });

      test('adds given objects', () {
        var box = BoxMock();
        var obj = _getHiveObject('key', box);

        var item1 = _getHiveObject('item1', box);
        var item2 = _getHiveObject('item2', box);
        var list = HiveListImpl(obj, box, objects: [item1, item2, item1]);

        expect(item1.debugRemoteHiveLists, {list: 2});
        expect(item2.debugRemoteHiveLists, {list: 1});
      });
    });

    test('HiveListImpl.lazy()', () {
      var list = HiveListImpl.lazy('testBox', ['key1', 'key2']);
      expect(list.boxName, 'testBox');
      expect(list.keys, ['key1', 'key2']);
    });

    group('.box', () {
      test('throws HiveError if box is not open', () {
        var hive = HiveImpl();
        var hiveList = HiveListImpl.lazy('someBox', [])..debugHive = hive;
        expect(() => hiveList.box, throwsHiveError('you have to open the box'));
      });

      test('returns the box', () async {
        var hive = HiveImpl();
        var box = await hive.openBox<int>('someBox', bytes: Uint8List(0));
        var hiveList = HiveListImpl.lazy('someBox', [])..debugHive = hive;
        expect(hiveList.box, box);
      });
    });

    group('.delegate', () {
      test('throws exception if HiveList is disposed', () {
        var list = HiveListImpl.lazy('box', []);
        list.dispose();
        expect(() => list.delegate, throwsHiveError('already been disposed'));
      });

      test('removes correct elements if invalidated', () {
        var box = BoxMock();
        var obj = _getHiveObject('key', box);

        var item1 = _getHiveObject('item1', box);
        var item2 = _getHiveObject('item2', box);
        var list = HiveListImpl(obj, box, objects: [item1, item2, item1]);

        item1.debugRemoteHiveLists.clear();
        expect(list.delegate, [item1, item2, item1]);
        list.invalidate();
        expect(list.delegate, [item2]);
      });

      test('creates delegate and links HiveList if delegate == null', () {
        var hive = HiveMock();
        var box = BoxMock();
        when(box.containsKey(any)).thenReturn(false);
        when(box.containsKey('item1')).thenReturn(true);
        when(box.containsKey('item2')).thenReturn(true);
        when(hive.getBoxWithoutCheckInternal('box')).thenReturn(box);

        var item1 = _getHiveObject('item1', box);
        var item2 = _getHiveObject('item2', box);

        var list = HiveListImpl.lazy('box', ['item1', 'none', 'item2', 'item1'])
          ..debugHive = hive;
        expect(list.delegate, [item1, item2, item1]);
        expect(item1.debugRemoteHiveLists, {list: 2});
        expect(item2.debugRemoteHiveLists, {list: 1});
      });
    });

    group('.dispose()', () {
      test('unlinks remote HiveObjects if delegate exists', () {
        var box = BoxMock();
        var obj = _getHiveObject('key', box);

        var item1 = _getHiveObject('item1', box);
        var item2 = _getHiveObject('item2', box);

        var list = HiveListImpl(obj, box, objects: [item1, item2, item1]);
        list.dispose();

        expect(item1.debugRemoteHiveLists, {});
        expect(item2.debugRemoteHiveLists, {});
      });

      test('unlinks HiveObject', () {
        var box = BoxMock();
        var obj = _getHiveObject('key', box);
        var list = HiveListImpl(obj, box);

        expect(obj.debughiveLists, [list]);
        list.dispose();
        expect(obj.debughiveLists, []);
      });
    });

    test('set length', () {
      var box = BoxMock();

      var obj = _getHiveObject('key', box);
      var item1 = _getHiveObject('item1', box);
      var item2 = _getHiveObject('item2', box);

      var list = HiveListImpl(obj, box, objects: [item1, item2]);
      list.length = 1;

      expect(item2.debugRemoteHiveLists, {});
      expect(list, [item1]);
    });

    group('operator []=', () {
      test('sets key at index', () {
        var box = BoxMock();

        var obj = _getHiveObject('key', box);
        var oldItem = _getHiveObject('old', box);
        var newItem = _getHiveObject('new', box);

        var list = HiveListImpl(obj, box, objects: [oldItem]);
        list[0] = newItem;

        expect(oldItem.debugRemoteHiveLists, {});
        expect(newItem.debugRemoteHiveLists, {list: 1});
        expect(list, [newItem]);
      });

      test('throws HiveError if HiveObject is not valid', () {
        var box = BoxMock();

        var obj = _getHiveObject('key', box);
        var oldItem = _getHiveObject('old', box);
        var newItem = _getHiveObject('new', BoxMock());

        var list = HiveListImpl(obj, box, objects: [oldItem]);
        expect(() => list[0] = newItem, throwsHiveError());
      });
    });

    group('.add()', () {
      test('adds key', () {
        var box = BoxMock();

        var obj = _getHiveObject('key', box);
        var item1 = _getHiveObject('item1', box);
        var item2 = _getHiveObject('item2', box);

        var list = HiveListImpl(obj, box, objects: [item1]);
        list.add(item2);

        expect(item2.debugRemoteHiveLists, {list: 1});
        expect(list, [item1, item2]);
      });

      test('throws HiveError if HiveObject is not valid', () {
        var box = BoxMock();

        var obj = _getHiveObject('key', box);
        var item = _getHiveObject('item', BoxMock());

        var list = HiveListImpl(obj, box);
        expect(() => list.add(item), throwsHiveError('needs to be in the box'));
      });
    });

    group('.addAll()', () {
      test('adds keys', () {
        var box = BoxMock();

        var obj = _getHiveObject('key', box);
        var item1 = _getHiveObject('item1', box);
        var item2 = _getHiveObject('item2', box);

        var list = HiveListImpl(obj, box, objects: [item1]);
        list.addAll([item2, item2]);

        expect(item2.debugRemoteHiveLists, {list: 2});
        expect(list, [item1, item2, item2]);
      });

      test('throws HiveError if HiveObject is not valid', () {
        var box = BoxMock();

        var obj = _getHiveObject('key', box);
        var item = _getHiveObject('item', BoxMock());

        var list = HiveListImpl(obj, box);
        expect(() => list.addAll([item]),
            throwsHiveError('needs to be in the box'));
      });
    });
  });
}
