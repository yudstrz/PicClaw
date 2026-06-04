abstract class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => message;
}

class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message);
}

class MediaPermissionFailure extends Failure {
  const MediaPermissionFailure(super.message);
}

class MediaAccessFailure extends Failure {
  const MediaAccessFailure(super.message);
}
