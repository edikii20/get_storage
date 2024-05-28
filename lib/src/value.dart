import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'dart:collection';

class ValueStorage<T> extends Value<T> {
  ValueStorage(T value) : super(value);

  Map<String, dynamic> changes = <String, dynamic>{};

  void changeValue(String key, dynamic value) {
    changes = {key: value};
    refresh();
  }
}

class Value<T> extends ListNotifier
    with StateMixin<T>
    implements ValueListenable<T?> {
  Value(T val) {
    _value = val;
    _fillEmptyStatus();
  }

  @override
  T? get value {
    notifyChildrens();
    return _value;
  }

  @override
  set value(T? newValue) {
    if (_value == newValue) return;
    _value = newValue;
    refresh();
  }

  T? call([T? v]) {
    if (v != null) {
      value = v;
    }
    return value;
  }

  void update(void Function(T? value) fn) {
    fn(value);
    refresh();
  }

  @override
  String toString() => value.toString();

  dynamic toJson() => (value as dynamic)?.toJson();
}

class RxStatus {
  final bool isLoading;
  final bool isError;
  final bool isSuccess;
  final bool isEmpty;
  final bool isLoadingMore;
  final String? errorMessage;

  RxStatus._({
    this.isEmpty = false,
    this.isLoading = false,
    this.isError = false,
    this.isSuccess = false,
    this.errorMessage,
    this.isLoadingMore = false,
  });

  factory RxStatus.loading() {
    return RxStatus._(isLoading: true);
  }

  factory RxStatus.loadingMore() {
    return RxStatus._(isSuccess: true, isLoadingMore: true);
  }

  factory RxStatus.success() {
    return RxStatus._(isSuccess: true);
  }

  factory RxStatus.error([String? message]) {
    return RxStatus._(isError: true, errorMessage: message);
  }

  factory RxStatus.empty() {
    return RxStatus._(isEmpty: true);
  }
}

mixin StateMixin<T> on ListNotifierMixin {
  T? _value;
  RxStatus? _status;

  bool _isNullOrEmpty(dynamic val) {
    if (val == null) return true;
    var result = false;
    if (val is Iterable) {
      result = val.isEmpty;
    } else if (val is String) {
      result = val.isEmpty;
    } else if (val is Map) {
      result = val.isEmpty;
    }
    return result;
  }

  void _fillEmptyStatus() {
    _status = _isNullOrEmpty(_value) ? RxStatus.loading() : RxStatus.success();
  }

  RxStatus get status {
    notifyChildrens();
    return _status ??= _status = RxStatus.loading();
  }

  T? get state => value;

  @protected
  T? get value {
    notifyChildrens();
    return _value;
  }

  @protected
  set value(T? newValue) {
    if (_value == newValue) return;
    _value = newValue;
    refresh();
  }

  @protected
  void change(T? newState, {RxStatus? status}) {
    bool canUpdate = false;
    if (status != null) {
      _status = status;
      canUpdate = true;
    }
    if (newState != _value) {
      _value = newState;
      canUpdate = true;
    }
    if (canUpdate) {
      refresh();
    }
  }

  void append(Future<T> Function() Function() body, {String? errorMessage}) {
    final compute = body();
    compute().then((newValue) {
      change(newValue, status: RxStatus.success());
    }, onError: (err) {
      change(state, status: RxStatus.error(errorMessage ?? err.toString()));
    });
  }
}

class ListNotifier extends Listenable with ListenableMixin, ListNotifierMixin {}

typedef GetStateUpdate = void Function();
typedef Disposer = void Function();

mixin ListenableMixin implements Listenable {}
mixin ListNotifierMixin on ListenableMixin {
  // int _version = 0;
  // int _microtask = 0;

  // int get notifierVersion => _version;
  // int get notifierMicrotask => _microtask;

  List<GetStateUpdate?>? _updaters = <GetStateUpdate?>[];

  HashMap<Object?, List<GetStateUpdate>>? _updatersGroupIds =
      HashMap<Object?, List<GetStateUpdate>>();

  @protected
  void refresh() {
    assert(_debugAssertNotDisposed());

    /// This debounce the call to update.
    /// It prevent errors and duplicates builds
    // if (_microtask == _version) {
    //   _microtask++;
    //   scheduleMicrotask(() {
    //     _version++;
    //     _microtask = _version;
    _notifyUpdate();
    // });
    // }
  }

  void _notifyUpdate() {
    for (var element in _updaters!) {
      element!();
    }
  }

  void _notifyIdUpdate(Object id) {
    if (_updatersGroupIds!.containsKey(id)) {
      final listGroup = _updatersGroupIds![id]!;
      for (var item in listGroup) {
        item();
      }
    }
  }

  @protected
  void refreshGroup(Object id) {
    assert(_debugAssertNotDisposed());

    // /// This debounce the call to update.
    // /// It prevent errors and duplicates builds
    // if (_microtask == _version) {
    //   _microtask++;
    //   scheduleMicrotask(() {
    //     _version++;
    //     _microtask = _version;
    _notifyIdUpdate(id);
    // });
    // }
  }

  bool _debugAssertNotDisposed() {
    assert(() {
      if (_updaters == null) {
        throw FlutterError('''A $runtimeType was used after being disposed.\n
'Once you have called dispose() on a $runtimeType, it can no longer be used.''');
      }
      return true;
    }());
    return true;
  }

  @protected
  void notifyChildrens() {
    TaskManager.instance.notify(_updaters);
  }

  bool get hasListeners {
    assert(_debugAssertNotDisposed());
    return _updaters!.isNotEmpty;
  }

  int get listeners {
    assert(_debugAssertNotDisposed());
    return _updaters!.length;
  }

  @override
  void removeListener(VoidCallback listener) {
    assert(_debugAssertNotDisposed());
    _updaters!.remove(listener);
  }

  void removeListenerId(Object id, VoidCallback listener) {
    assert(_debugAssertNotDisposed());
    if (_updatersGroupIds!.containsKey(id)) {
      _updatersGroupIds![id]!.remove(listener);
    }
    _updaters!.remove(listener);
  }

  @mustCallSuper
  void dispose() {
    assert(_debugAssertNotDisposed());
    _updaters = null;
    _updatersGroupIds = null;
  }

  @override
  Disposer addListener(GetStateUpdate listener) {
    assert(_debugAssertNotDisposed());
    _updaters!.add(listener);
    return () => _updaters!.remove(listener);
  }

  Disposer addListenerId(Object? key, GetStateUpdate listener) {
    _updatersGroupIds![key] ??= <GetStateUpdate>[];
    _updatersGroupIds![key]!.add(listener);
    return () => _updatersGroupIds![key]!.remove(listener);
  }

  /// To dispose an [id] from future updates(), this ids are registered
  /// by `GetBuilder()` or similar, so is a way to unlink the state change with
  /// the Widget from the Controller.
  void disposeId(Object id) {
    _updatersGroupIds!.remove(id);
  }
}

class TaskManager {
  TaskManager._();

  static TaskManager? _instance;

  static TaskManager get instance => _instance ??= TaskManager._();

  GetStateUpdate? _setter;

  List<VoidCallback>? _remove;

  void notify(List<GetStateUpdate?>? updaters) {
    if (_setter != null) {
      if (!updaters!.contains(_setter)) {
        updaters.add(_setter);
        _remove!.add(() => updaters.remove(_setter));
      }
    }
  }

  Widget exchange(
    List<VoidCallback> disposers,
    GetStateUpdate setState,
    Widget Function(BuildContext) builder,
    BuildContext context,
  ) {
    _remove = disposers;
    _setter = setState;
    final result = builder(context);
    _remove = null;
    _setter = null;
    return result;
  }
}
