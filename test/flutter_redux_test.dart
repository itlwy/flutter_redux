import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StoreProvider', () {
    testWidgets('passes a Redux Store down to its descendants',
        (WidgetTester tester) async {
      final widget = StoreProvider<String>(
        storeBuilder: () => Store<String>(
          {'test': identityReducer},
          initialState: 'I',
        ),
        child: StoreCaptor<String>(),
      );

      await tester.pumpWidget(widget);

      final captor =
          tester.firstWidget<StoreCaptor>(find.byKey(StoreCaptor.captorKey));

      expect(captor.store, StoreContext.instance.find<String>());
    });

    testWidgets('throws a helpful message if no provider found',
        (WidgetTester tester) async {
      final store = Store<String>(
        identityReducer,
        initialState: 'I',
      );
      final widget = StoreProvider<String>(
        store: store,
        child: StoreCaptor<int>(),
      );

      await tester.pumpWidget(widget);

      expect(tester.takeException(), isInstanceOf<StoreProviderError>());
    });

    testWidgets('should update the children if the store changes',
        (WidgetTester tester) async {
      Widget widget(String state) {
        return StoreProvider<String>(
          store: Store<String>(
            identityReducer,
            initialState: state,
          ),
          child: StoreCaptor<String>(),
        );
      }

      await tester.pumpWidget(widget('I'));
      await tester.pumpWidget(widget('A'));

      final captor =
          tester.firstWidget<StoreCaptor>(find.byKey(StoreCaptor.captorKey));

      expect(captor.store.state, 'A');
    });
  });

  group('StoreConnector', () {
    testWidgets('initially builds from the current state of the store',
        (WidgetTester tester) async {
      final widget = StoreProvider<String>(
        store: Store<String>(identityReducer, initialState: 'I'),
        child: StoreBuilder<String>(
          builder: (context, store) {
            return Text(
              store.state,
              textDirection: TextDirection.ltr,
            );
          },
        ),
      );

      await tester.pumpWidget(widget);

      expect(find.text('I'), findsOneWidget);
    });

    testWidgets('can convert the store to a ViewModel',
        (WidgetTester tester) async {
      final widget = StoreProvider<String>(
        store: Store<String>(identityReducer, initialState: 'I'),
        child: StoreConnector<String, String>(
          converter: selector,
          builder: (context, latest) {
            return Text(
              latest,
              textDirection: TextDirection.ltr,
            );
          },
        ),
      );

      await tester.pumpWidget(widget);

      expect(find.text('I'), findsOneWidget);
    });

    testWidgets('supports a nullable ViewModel', (WidgetTester tester) async {
      final widget = StoreProvider<String?>(
        store: Store<String?>(identityReducer, initialState: null),
        child: StoreConnector<String?, String?>(
          converter: (store) => store.state,
          builder: (context, latest) {
            return Text(
              latest ?? 'N',
              textDirection: TextDirection.ltr,
            );
          },
        ),
      );

      await tester.pumpWidget(widget);

      expect(find.text('N'), findsOneWidget);
    });

    testWidgets('supports a nullable ViewModel (rebuildOnChange: false)',
        (WidgetTester tester) async {
      final widget = StoreProvider<String?>(
        store: Store<String?>(identityReducer, initialState: null),
        child: StoreConnector<String?, String?>(
          converter: (store) => store.state,
          rebuildOnChange: false,
          builder: (context, latest) {
            return Text(
              latest ?? 'N',
              textDirection: TextDirection.ltr,
            );
          },
        ),
      );

      await tester.pumpWidget(widget);

      expect(find.text('N'), findsOneWidget);
    });

    testWidgets('supports a nullable ViewModel (onInitialBuild)',
        (WidgetTester tester) async {
      String? data = 'hello';

      final widget = StoreProvider<String?>(
        store: Store<String?>(identityReducer, initialState: null),
        child: StoreConnector<String?, String?>(
          converter: (store) => store.state,
          onInitialBuild: (vm) => data = vm,
          builder: (context, vm) => Container(),
        ),
      );

      await tester.pumpWidget(widget);

      expect(data, equals(null));
    });

    testWidgets('supports a nullable ViewModel (onDidChange)',
        (WidgetTester tester) async {
      String? data = 'hello';

      final store = Store<String?>(
        identityReducer,
        initialState: 'world',
      );

      final widget = StoreProvider<String?>(
        store: store,
        child: StoreConnector<String?, String?>(
          converter: (store) => store.state,
          onDidChange: (prevVm, vm) => data = vm,
          builder: (context, vm) => Container(),
        ),
      );

      await tester.pumpWidget(widget);

      store.dispatch(null);

      await tester.pumpWidget(widget);

      expect(data, equals(null));
    });

    testWidgets('supports a nullable ViewModel (nested)',
        (WidgetTester tester) async {
      final widget = StoreProvider<StateWithNullable>(
        store: Store<StateWithNullable>(
          identityReducer,
          initialState: StateWithNullable(),
        ),
        child: StoreConnector<StateWithNullable, int?>(
          converter: (store) => store.state.data,
          builder: (context, int? data) {
            return Text(
              data != null ? '$data' : 'no data',
              textDirection: TextDirection.ltr,
            );
          },
        ),
      );

      await tester.pumpWidget(widget);

      expect(find.text('no data'), findsOneWidget);
    });

    testWidgets('converter errors in initState are thrown by the Widget',
        (WidgetTester tester) async {
      final widget = StoreProvider<String>(
        store: Store<String>(identityReducer, initialState: 'I'),
        child: StoreConnector<String, String>(
          converter: (_) => throw StateError('A'),
          builder: (context, latest) {
            return Text(
              latest,
              textDirection: TextDirection.ltr,
            );
          },
        ),
      );

      await tester.pumpWidget(widget);

      expect(tester.takeException(), isInstanceOf<ConverterError>());
    });

    testWidgets('converter errors from the stream are thrown by the Widget',
        (WidgetTester tester) async {
      var count = 0;
      final store = Store<String>(identityReducer, initialState: 'I');
      final widget = StoreProvider<String>(
        store: store,
        child: StoreConnector<String, String>(
          converter: (store) {
            if (count == 0) {
              count++;
              return store.state.toString();
            }

            throw StateError('A');
          },
          builder: (context, latest) {
            return Text(
              latest,
              textDirection: TextDirection.ltr,
            );
          },
        ),
      );

      await tester.pumpWidget(widget);
      expect(tester.takeException(), isNull);

      store.dispatch('U');
      await tester.pumpWidget(widget);

      expect(tester.takeException(), isInstanceOf<ConverterError>());
    });

    testWidgets('builds the latest state of the store after a change event',
        (WidgetTester tester) async {
      final store = Store<String>(
        identityReducer,
        initialState: 'I',
      );
      final widget = StoreProvider<String>(
        store: store,
        child: StoreBuilder<String>(
          builder: (context, store) {
            return Text(
              store.state,
              textDirection: TextDirection.ltr,
            );
          },
        ),
      );

      // Build the widget with the initial state
      await tester.pumpWidget(widget);

      // Dispatch a action
      store.dispatch('A');

      // Build the widget again with the state
      await tester.pumpWidget(widget);

      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('rebuilds by default whenever the store emits a change',
        (WidgetTester tester) async {
      var numBuilds = 0;
      final store = Store<String>(
        identityReducer,
        initialState: 'I',
      );
      final widget = StoreProvider<String>(
        store: store,
        child: StoreConnector<String, String>(
          converter: selector,
          builder: (context, latest) {
            numBuilds++;

            return Container();
          },
        ),
      );

      // Build the widget with the initial state
      await tester.pumpWidget(widget);

      expect(numBuilds, 1);

      // Dispatch the exact same event. This should still trigger a rebuild
      store.dispatch('I');

      await tester.pumpWidget(widget);

      expect(numBuilds, 2);
    });

    testWidgets('can access store from initState', (WidgetTester tester) async {
      final store = Store<String>(
        identityReducer,
        initialState: 'I',
      );
      final widget = StoreProvider<String>(
        store: store,
        child: StoreCaptorStateful(),
      );

      // Build the widget with the initial state
      await tester.pumpWidget(widget);

      // Check whether the store it captures is the same as the store created at the beginning
      expect(StoreCaptorStateful.captorKey.currentState?.store, store);
    });

    testWidgets('does not rebuild if rebuildOnChange is set to false',
        (WidgetTester tester) async {
      var numBuilds = 0;
      final store = Store<String>(
        identityReducer,
        initialState: 'I',
      );
      final widget = StoreProvider<String>(
        store: store,
        child: StoreConnector<String, String>(
          converter: selector,
          rebuildOnChange: false,
          builder: (context, latest) {
            numBuilds++;

            return Container();
          },
        ),
      );

      // Build the widget with the initial state
      await tester.pumpWidget(widget);

      expect(numBuilds, 1);

      // Dispatch the exact same event. This will cause a change on the Store,
      // but would result in no change to the UI since `rebuildOnChange` is
      // false.
      //
      // By default, this should still trigger a rebuild
      store.dispatch('I');

      await tester.pumpWidget(widget);

      expect(numBuilds, 1);
    });

    testWidgets('does not rebuild if ignoreChange returns true',
        (WidgetTester tester) async {
      var numBuilds = 0;
      final store = Store<String>(
        identityReducer,
        initialState: 'I',
      );
      final widget = StoreProvider<String>(
        store: store,
        child: StoreConnector<String, String>(
          ignoreChange: (dynamic state) => state == 'N',
          converter: selector,
          builder: (context, latest) {
            numBuilds++;

            return Container();
          },
        ),
      );

      // Build the widget with the initial state
      await tester.pumpWidget(widget);

      expect(numBuilds, 1);

      // Dispatch a null value. This will cause a change on the Store,
      // but would result in no rebuild since the `converter` is returning
      // this null value.
      store.dispatch('N');

      await tester.pumpWidget(widget);

      expect(numBuilds, 1);
    });

    testWidgets('runs a function when initialized',
        (WidgetTester tester) async {
      var numBuilds = 0;
      final counter = CallCounter<Store<String>>();
      final store = Store<String>(
        identityReducer,
        initialState: 'A',
      );
      Widget widget() {
        return StoreProvider<String>(
          store: store,
          child: StoreConnector<String, String>(
            onInit: counter,
            converter: selector,
            builder: (context, latest) {
              numBuilds++;

              return Container();
            },
          ),
        );
      }

      // Build the widget with the initial state
      await tester.pumpWidget(widget());

      // Expect the Widget to be rebuilt and the onInit method to be called
      expect(counter.callCount, 1);
      expect(numBuilds, 1);

      store.dispatch('A');

      // Rebuild the widget
      await tester.pumpWidget(widget());

      // Expect the Widget to be rebuilt, but the onInit method should NOT be
      // called a second time.
      expect(numBuilds, 2);
      expect(counter.callCount, 1);

      store.dispatch('just to be sure');

      // Rebuild the widget
      await tester.pumpWidget(widget());

      // Expect the Widget to be rebuilt, but the onInit method should NOT be
      // called a third time.
      expect(numBuilds, 3);
      expect(counter.callCount, 1);
    });

    testWidgets('onInit is called before the first ViewModel is built',
        (WidgetTester tester) async {
      String? currentState;
      final store = Store<String>(
        identityReducer,
        initialState: 'I',
      );
      Widget widget() {
        return StoreProvider<String>(
          store: store,
          child: StoreConnector<String, String>(
            converter: selector,
            onInit: (store) {
              store.dispatch('A');
            },
            builder: (context, state) {
              currentState = state;
              return Container();
            },
          ),
        );
      }

      // Build the widget with the initial state
      await tester.pumpWidget(widget());

      // Expect the Widget to be rebuilt and the onInit method to be called
      expect(currentState, 'A');
    });

    testWidgets('runs a function before rebuild', (WidgetTester tester) async {
      final states = <BuildState>[];
      final store = Store<String>(identityReducer, initialState: 'A');

      Widget widget() => StoreProvider<String>(
            store: store,
            child: StoreConnector<String, String>(
              onWillChange: (_, __) => states.add(BuildState.before),
              converter: (store) => store.state,
              builder: (context, latest) {
                states.add(BuildState.during);
                return Container();
              },
            ),
          );

      await tester.pumpWidget(widget());

      expect(states, [BuildState.during]);

      store.dispatch('A');
      await tester.pumpWidget(widget());

      expect(states, [BuildState.during, BuildState.before, BuildState.during]);
    });

    testWidgets('runs a function after initial build',
        (WidgetTester tester) async {
      final states = <BuildState>[];
      final store = Store<String>(identityReducer, initialState: 'A');

      Widget widget() => StoreProvider<String>(
            store: store,
            child: StoreConnector<String, String>(
              onInitialBuild: (_) => states.add(BuildState.after),
              converter: (store) => store.state,
              builder: (context, latest) {
                states.add(BuildState.during);
                return Container();
              },
            ),
          );

      await tester.pumpWidget(widget());

      expect(states, [BuildState.during, BuildState.after]);

      // Should not run the onInitialBuild function again
      await tester.pump();
      expect(states, [BuildState.during, BuildState.after]);
    });

    testWidgets('runs a function after build when the vm changes',
        (WidgetTester tester) async {
      final states = <BuildState>[];
      final store = Store<String>(identityReducer, initialState: 'A');
      String? previousViewModel;
      String? nextViewModel;

      Widget widget() => StoreProvider<String>(
            store: store,
            child: StoreConnector<String, String>(
              onDidChange: (prev, next) {
                previousViewModel = prev;
                nextViewModel = next;
                states.add(BuildState.after);
              },
              converter: (store) => store.state,
              builder: (context, latest) {
                states.add(BuildState.during);
                return Container();
              },
            ),
          );

      // Does not initially call callback
      await tester.pumpWidget(widget());
      expect(states, [BuildState.during]);

      // Runs the callback after the second build
      store.dispatch('N');
      await tester.pumpWidget(widget());
      expect(states, [BuildState.during, BuildState.during, BuildState.after]);
      expect(previousViewModel, 'A');
      expect(nextViewModel, 'N');

      // Does not run the callback if the VM has not changed
      await tester.pumpWidget(widget());
      expect(states, [
        BuildState.during,
        BuildState.during,
        BuildState.after,
        BuildState.during,
      ]);
    });

    testWidgets('runs a function when disposed', (WidgetTester tester) async {
      final counter = CallCounter<Store<String>>();
      final store = Store<String>(
        identityReducer,
        initialState: 'A',
      );
      Widget widget() {
        return StoreProvider<String>(
          store: store,
          child: StoreConnector<String, String>(
            onDispose: counter,
            converter: selector,
            builder: (context, latest) => Container(),
          ),
        );
      }

      // Build the widget with the initial state
      await tester.pumpWidget(widget());

      // onDispose should not be called yet.
      expect(counter.callCount, 0);

      store.dispatch('A');

      // Rebuild a different widget tree. Expect this to trigger `onDispose`.
      await tester.pumpWidget(Container());

      expect(counter.callCount, 1);
    });

    testWidgets(
        'avoids rebuilds when distinct is used with a class that implements ==',
        (WidgetTester tester) async {
      var numBuilds = 0;
      final store = Store<String>(
        identityReducer,
        initialState: 'I',
      );
      final widget = StoreProvider<String>(
        store: store,
        child: StoreConnector<String, String>(
          // Same exact setup as the previous test, but distinct is set to true.
          distinct: true,
          converter: selector,
          builder: (context, latest) {
            numBuilds++;

            return Container();
          },
        ),
      );

      // Build the widget with the initial state
      await tester.pumpWidget(widget);

      expect(numBuilds, 1);

      // Dispatch another action of the same type
      store.dispatch('I');

      await tester.pumpWidget(widget);

      expect(numBuilds, 1);

      // Dispatch another action of a different type. This should trigger
      // another rebuild
      store.dispatch('A');

      await tester.pumpWidget(widget);

      expect(numBuilds, 2);
    });

    group('Updates', () {
      testWidgets(
        'converter update results in proper rebuild',
        (WidgetTester tester) async {
          String? currentState;
          final store = Store<String>(
            identityReducer,
            initialState: 'I',
          );
          Widget widget([StoreConverter<String, String> converter = selector]) {
            return StoreProvider<String>(
              store: store,
              child: StoreConnector<String, String>(
                converter: converter,
                onInit: (store) => store.dispatch('A'),
                builder: (context, vm) {
                  currentState = vm;
                  return Container();
                },
              ),
            );
          }

          // Build the widget with the initial state
          await tester.pumpWidget(widget());

          // Expect the Widget to be rebuilt and the onInit method to be called
          expect(currentState, 'A');

          // Rebuild the widget with a new converter
          await tester.pumpWidget(widget((Store<String> s) => 'B'));

          // Expect the Widget to be rebuilt and the converter should be rerun
          expect(currentState, 'B');
        },
      );

      testWidgets(
        'onDidChange works as expected',
        (WidgetTester tester) async {
          String? currentState;
          final store = Store<String>(
            identityReducer,
            initialState: 'I',
          );
          Widget widget([
            void Function(String? old, String viewModel)? onDidChange,
          ]) {
            return StoreProvider<String>(
              store: store,
              child: StoreConnector<String, String>(
                converter: selector,
                onDidChange: onDidChange,
                onInit: (store) => store.dispatch('A'),
                builder: (context, vm) {
                  return Container();
                },
              ),
            );
          }

          // Build the widget with the initial state
          await tester.pumpWidget(widget());

          // No onDidChange function to run, so currentState should be null
          expect(currentState, isNull);

          // Build the widget with a new onDidChange
          final newWidget = widget((_, __) => currentState = 'S');
          await tester.pumpWidget(newWidget);

          // Dispatch a new value, which should cause onDidChange to run
          store.dispatch('B');

          // Run pumpWidget, which should flush the after build (didChange)
          // callbacks
          await tester.pumpWidget(newWidget);

          // Expect our new onDidChange to run
          expect(currentState, 'S');
        },
      );

      testWidgets('onDidChange errors are thrown by the Widget',
          (WidgetTester tester) async {
        final store = Store<String>(identityReducer, initialState: 'I');
        final widget = StoreProvider<String>(
          store: store,
          child: StoreConnector<String, String>(
            converter: (store) => store.state,
            onDidChange: (_, __) => throw StateError('OnDidChange Error'),
            builder: (context, latest) {
              return Text(
                latest,
                textDirection: TextDirection.ltr,
              );
            },
          ),
        );

        await tester.pumpWidget(widget);

        // Dispatch a new value, which should cause onWillChange to run
        store.dispatch('B');

        // Pump the widget tree display any errors
        await tester.pumpAndSettle();

        expect(tester.takeException(), isInstanceOf<StateError>());
      });
      testWidgets(
        'onWillChange works as expected',
        (WidgetTester tester) async {
          String? prevVm;
          String? nextVm;
          final store = Store<String>(
            identityReducer,
            initialState: 'I',
          );
          Widget widget([
            void Function(String? prev, String current)? onWillChange,
          ]) {
            return StoreProvider<String>(
              store: store,
              child: StoreConnector<String, String>(
                converter: selector,
                onWillChange: onWillChange,
                onInit: (store) => store.dispatch('A'),
                builder: (context, vm) {
                  return Container();
                },
              ),
            );
          }

          // Build the widget with the initial state
          await tester.pumpWidget(widget());

          // No onWillChange function to run, so currentState should be null
          expect(prevVm, isNull);
          expect(nextVm, isNull);

          // Build the widget with a new onWillChange
          final newWidget = widget((prev, next) {
            prevVm = prev;
            nextVm = next;
          });
          await tester.pumpWidget(newWidget);

          // Dispatch a new value, which should cause onWillChange to run
          store.dispatch('B');

          // Run pumpWidget, which should flush the after build (didChange)
          // callbacks
          await tester.pumpWidget(newWidget);

          // Expect our new onWillChange to run
          expect(prevVm, 'A');
          expect(nextVm, 'B');
        },
      );

      testWidgets('onWillChange errors are thrown by the Widget',
          (WidgetTester tester) async {
        final store = Store<String>(identityReducer, initialState: 'I');
        final widget = StoreProvider<String>(
          store: store,
          child: StoreConnector<String, String>(
            converter: (store) => store.state,
            onWillChange: (_, __) => throw StateError('onWillChange Error'),
            builder: (context, latest) {
              return Text(
                latest,
                textDirection: TextDirection.ltr,
              );
            },
          ),
        );

        await tester.pumpWidget(widget);

        // Dispatch a new value, which should cause onWillChange to run
        store.dispatch('B');

        // Pump the widget tree display any errors
        await tester.pumpAndSettle();

        expect(tester.takeException(), isInstanceOf<StateError>());
      });
    });
  });

  group('StoreBuilder', () {
    testWidgets('runs a function when initialized',
        (WidgetTester tester) async {
      var numBuilds = 0;
      final counter = CallCounter<Store<String>>();
      final store = Store<String>(
        identityReducer,
        initialState: 'A',
      );
      Widget widget() {
        return StoreProvider<String>(
          store: store,
          child: StoreBuilder<String>(
            onInit: counter,
            builder: (context, store) {
              numBuilds++;

              return Container();
            },
          ),
        );
      }

      // Build the widget with the initial state
      await tester.pumpWidget(widget());

      // Expect the Widget to be rebuilt and the onInit method to be called
      expect(counter.callCount, 1);
      expect(numBuilds, 1);

      store.dispatch('A');

      // Rebuild the widget
      await tester.pumpWidget(widget());

      // Expect the Widget to be rebuilt, but the onInit method should NOT be
      // called a second time.
      expect(numBuilds, 2);
      expect(counter.callCount, 1);

      store.dispatch('just to be sure');

      // Rebuild the widget
      await tester.pumpWidget(widget());

      // Expect the Widget to be rebuilt, but the onInit method should NOT be
      // called a third time.
      expect(numBuilds, 3);
      expect(counter.callCount, 1);
    });

    testWidgets('runs a function before rebuild', (WidgetTester tester) async {
      final counter = CallCounter<Store<String>>();
      final store = Store<String>(identityReducer, initialState: 'A');

      Widget widget() {
        return StoreProvider(
          store: store,
          child: StoreBuilder<String>(
            onWillChange: counter,
            builder: (context, latest) => Container(),
          ),
        );
      }

      await tester.pumpWidget(widget());

      expect(counter.callCount, 0);

      store.dispatch('A');
      await tester.pumpWidget(widget());

      expect(counter.callCount, 1);
    });

    testWidgets('runs a function after initial build',
        (WidgetTester tester) async {
      final states = <BuildState>[];
      final store = Store<String>(identityReducer, initialState: 'A');

      Widget widget() => StoreProvider<String>(
            store: store,
            child: StoreBuilder<String>(
              onInitialBuild: (_) => states.add(BuildState.after),
              builder: (context, latest) {
                states.add(BuildState.during);
                return Container();
              },
            ),
          );

      await tester.pumpWidget(widget());

      expect(states, [BuildState.during, BuildState.after]);

      // Should not run the onInitialBuild function again
      await tester.pump();
      expect(states, [BuildState.during, BuildState.after]);
    });

    testWidgets('runs a function after build when the vm changes',
        (WidgetTester tester) async {
      final states = <BuildState>[];
      final store = Store<String>(identityReducer, initialState: 'A');

      Widget widget() => StoreProvider<String>(
            store: store,
            child: StoreBuilder<String>(
              onDidChange: (_, __) => states.add(BuildState.after),
              builder: (context, latest) {
                states.add(BuildState.during);
                return Container();
              },
            ),
          );

      // Does not initially call callback
      await tester.pumpWidget(widget());
      expect(states, [BuildState.during]);

      // Runs the callback after the second build
      store.dispatch('N');
      await tester.pumpWidget(widget());
      expect(states, [BuildState.during, BuildState.during, BuildState.after]);

      // Does not run the callback if the VM has not changed
      await tester.pumpWidget(widget());
      expect(states, [
        BuildState.during,
        BuildState.during,
        BuildState.after,
        BuildState.during,
      ]);
    });

    testWidgets('runs a function when disposed', (WidgetTester tester) async {
      final counter = CallCounter<Store<String>>();
      final store = Store<String>(
        identityReducer,
        initialState: 'init',
      );
      Widget widget() {
        return StoreProvider<String>(
          store: store,
          child: StoreBuilder<String>(
            onDispose: counter,
            builder: (context, store) => Container(),
          ),
        );
      }

      // Build the widget with the initial state
      await tester.pumpWidget(widget());

      expect(counter.callCount, 0);

      store.dispatch('A');

      // Rebuild a different widget, should trigger a dispose as the
      // StoreBuilder has been removed from the Widget tree.
      await tester.pumpWidget(Container());

      expect(counter.callCount, 1);
    });
  });
}

String selector(Store<String> store) => store.state;

// ignore: must_be_immutable
class StoreCaptor<S> extends StatelessWidget {
  static const Key captorKey = Key('StoreCaptor');

  late Store<S> store;

  StoreCaptor() : super(key: captorKey);

  @override
  Widget build(BuildContext context) {
    store = StoreProvider.of<S>(context);

    return Container();
  }
}

class StoreCaptorStateful extends StatefulWidget {
  static GlobalKey<_StoreCaptorStatefulState> captorKey =
      GlobalKey<_StoreCaptorStatefulState>();

  StoreCaptorStateful() : super(key: captorKey);

  @override
  _StoreCaptorStatefulState createState() => _StoreCaptorStatefulState();
}

class _StoreCaptorStatefulState extends State<StoreCaptorStateful> {
  late Store<String> store;

  @override
  void initState() {
    super.initState();
    store = StoreProvider.of<String>(context, listen: false);
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

T identityReducer<T>(T state, dynamic action) {
  return action as T;
}

class StateWithNullable {
  StateWithNullable({this.data});

  final int? data;
}

class CallCounter<S> {
  final List<S?> states = [];
  final List<S?> states2 = [];

  int get callCount => states.length;

  void call(S? s1, [S? s2]) {
    states.add(s1);
    states2.add(s2);
  }
}

enum BuildState { before, during, after }
