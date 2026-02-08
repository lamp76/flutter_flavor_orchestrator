/// Flutter Flavor Orchestrator
///
/// A comprehensive build-time orchestrator for managing Flutter flavors,
/// native configurations, and provisioning files across Android and iOS
/// platforms.
///
/// This library provides a clean, programmatic API for manipulating
/// native configuration files, managing app flavors, and automating the
/// build setup process.
library;

export 'src/config_parser.dart';
export 'src/models/flavor_config.dart';
export 'src/models/provisioning_config.dart';
export 'src/orchestrator.dart';
export 'src/processors/android_processor.dart';
export 'src/processors/ios_processor.dart';
export 'src/utils/file_manager.dart';
export 'src/utils/logger.dart';
