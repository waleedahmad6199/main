import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/project_model.dart';
import '../models/simulation_log_model.dart';
import '../models/task_model.dart';
import '../models/user_model.dart';

class DatabaseService {
  // Get an instance of the Firestore database
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- CREATE USER ---
  Future<void> createUser(UserModel user) async {
    // Looks for the 'users' collection. If it doesn't exist, Firebase creates it.
    // Creates a document using the user's ID, and saves the Map.
    await _db.collection('users').doc(user.id).set(user.toMap());
  }

  // --- CREATE PROJECT ---
  Future<void> createProject(ProjectModel project) async {
    await _db.collection('projects').doc(project.id).set(project.toMap());
  }

  // --- CREATE TASK ---
  Future<void> createTask(TaskModel task) async {
    await _db.collection('tasks').doc(task.id).set(task.toMap());
  }

  // --- CREATE SIMULATION LOG ---
  Future<void> createSimulationLog(SimulationLogModel log) async {
    await _db.collection('simulations').doc(log.id).set(log.toMap());
  }
}
