import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/core/logic/repository/listing_repo_helper.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';

import '../model/course_class.dart';

class CourseClassRepository
    with RepoNetworkHelper, ListingRepoHelper<CourseClass> {
  static final provider = Provider<CourseClassRepository>((ref) {
    return CourseClassRepository(ref.watch(ServerProvider.repoConfigProvider));
  });
  @override
  final RepoNetworkConfig config;

  CourseClassRepository(this.config);

  @override
  String get endPoint => "allcourse/events";

  @override
  CourseClass Function(Map p1) get fromMap => CourseClass.fromJson;
}
