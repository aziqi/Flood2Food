import '../../models/sensor_data.dart';

abstract class GamificationEvent {}

class GenerateDailyTasks extends GamificationEvent {
  final SensorData sensorData;
  final bool forceRefresh;
  GenerateDailyTasks(this.sensorData, {this.forceRefresh = false});
}

class CompleteTask extends GamificationEvent {
  final String taskId;
  CompleteTask(this.taskId);
}

class ResetGamificationData extends GamificationEvent {}

class UpdateProfileDetails extends GamificationEvent {
  final String? name;
  final String? avatarPath;
  UpdateProfileDetails({this.name, this.avatarPath});
}

