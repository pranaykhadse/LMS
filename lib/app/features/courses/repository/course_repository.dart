import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/core/logic/repository/listing_repo_helper.dart';
import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/features/courses/model/course.dart';

class CourseRepository with RepoNetworkHelper, ListingRepoHelper<Course> {
  static final provider = Provider<CourseRepository>((ref) {
    return CourseRepository(ref.watch(ServerProvider.repoConfigProvider));
  });
  @override
  final RepoNetworkConfig config;

  CourseRepository(this.config);

  @override
  String get endPoint => "allcourse/course-roaster";

  @override
  Course Function(Map p1) get fromMap => Course.fromJson;
}
