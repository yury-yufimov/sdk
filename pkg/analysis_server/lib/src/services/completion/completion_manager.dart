// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.completion.computer;

import 'dart:async';

import 'package:analysis_server/src/protocol.dart';
import 'package:analysis_server/src/services/completion/dart_completion_manager.dart';
import 'package:analysis_server/src/services/search/search_engine.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/source.dart';

/**
 * [CompletionCache] contains information about the prior code completion
 * for use in the next code completion.
 */
abstract class CompletionCache {

  /**
   * The context in which the completion was computed.
   */
  final AnalysisContext context;

  /**
   * The source in which the completion was computed.
   */
  final Source source;

  CompletionCache(this.context, this.source);
}

/**
 * Manages `CompletionComputer`s for a given completion request.
 */
abstract class CompletionManager {

  /**
   * The controller used for returning completion results.
   */
  StreamController<CompletionResult> controller;

  CompletionManager();

  /**
   * Create a manager for the given request.
   */
  factory CompletionManager.create(AnalysisContext context, Source source,
      int offset, SearchEngine searchEngine, CompletionCache cache,
      CompletionPerformance performance) {
    if (context != null) {
      if (AnalysisEngine.isDartFileName(source.shortName)) {
        return new DartCompletionManager.create(
            context,
            searchEngine,
            source,
            offset,
            cache,
            performance);
      }
      if (AnalysisEngine.isHtmlFileName(source.shortName)) {
        //TODO (danrubel) implement
//        return new HtmlCompletionManager(context, searchEngine, source, offset);
      }
    }
    return new NoOpCompletionManager(source, offset);
  }

  /**
   * Return cached information from the current completion operation
   * if there is any. Subclasses may override this method.
   */
  CompletionCache get completionCache => null;

  /**
   * Compute completion results and append them to the stream.
   * Clients should not call this method directly as it is automatically called
   * when a client listens to the stream returned by [results].
   * Subclasses should override this method, append at least one result
   * to the [controller], and close the controller stream once complete.
   */
  void compute();

  /**
   * Generate a stream of code completion results.
   */
  Stream<CompletionResult> results() {
    controller = new StreamController<CompletionResult>(onListen: () {
      scheduleMicrotask(compute);
    });
    return controller.stream;
  }
}

/**
 * Overall performance of a code completion operation.
 */
class CompletionPerformance {
  final Map<String, Duration> _startTimes = new Map<String, Duration>();
  final Stopwatch _stopwatch = new Stopwatch();
  final List<OperationPerformance> operations = <OperationPerformance>[];

  CompletionPerformance() {
    _stopwatch.start();
  }

  void complete() {
    _stopwatch.stop();
    _logDuration('total time', _stopwatch.elapsed);
  }

  logElapseTime(String tag, [f() = null]) {
    Duration start;
    Duration end = _stopwatch.elapsed;
    var result;
    if (f == null) {
      start = _startTimes[tag];
      if (start == null) {
        _logDuration(tag, null);
        return null;
      }
    } else {
      result = f();
      start = end;
      end = _stopwatch.elapsed;
    }
    _logDuration(tag, end - start);
    return result;
  }

  void logStartTime(String tag) {
    _startTimes[tag] = _stopwatch.elapsed;
  }

  void _logDuration(String tag, Duration elapsed) {
    operations.add(new OperationPerformance(tag, elapsed));
  }
}

/**
 * Code completion result generated by an [CompletionManager].
 */
class CompletionResult {

  /**
   * The length of the text to be replaced if the remainder of the identifier
   * containing the cursor is to be replaced when the suggestion is applied
   * (that is, the number of characters in the existing identifier).
   */
  final int replacementLength;

  /**
   * The offset of the start of the text to be replaced. This will be different
   * than the offset used to request the completion suggestions if there was a
   * portion of an identifier before the original offset. In particular, the
   * replacementOffset will be the offset of the beginning of said identifier.
   */
  final int replacementOffset;

  /**
   * The suggested completions.
   */
  final List<CompletionSuggestion> suggestions;

  /**
   * `true` if this is that last set of results that will be returned
   * for the indicated completion.
   */
  final bool last;

  CompletionResult(this.replacementOffset, this.replacementLength,
      this.suggestions, this.last);
}

class NoOpCompletionManager extends CompletionManager {
  final Source source;
  final int offset;

  NoOpCompletionManager(this.source, this.offset);

  @override
  void compute() {
    controller.add(new CompletionResult(offset, 0, [], true));
  }
}

/**
 * The performance of an operation when computing code completion.
 */
class OperationPerformance {

  /**
   * The name of the operation
   */
  final String name;

  /**
   * The elapse time or `null` if undefined.
   */
  final Duration elapsed;

  OperationPerformance(this.name, this.elapsed);
}
