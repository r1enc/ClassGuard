import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/exam.dart';

class ExamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Initializes a new exam session and stores all associated questions in a secure subcollection
  Future<void> createExamSession(Exam exam, List<Question> questions, String examType) async {
    try {
      DocumentReference examRef = _firestore.collection('exams').doc();
      WriteBatch batch = _firestore.batch();

      Map<String, dynamic> examData = exam.toJson();
      examData['examType'] = examType;

      batch.set(examRef, examData);

      // Store questions systematically using batch writes to ensure atomic data insertion
      for (var question in questions) {
        DocumentReference questionRef = examRef.collection('questions').doc();
        batch.set(questionRef, question.toJson());
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to create exam session: $e');
    }
  }

  // Validates the exam code and registers a student into the session's active submission pool
  Future<Map<String, String>> joinExamSession(String examCode, String studentName) async {
    try {
      String uid = FirebaseAuth.instance.currentUser?.uid ?? "";

      // Locate the active exam room corresponding to the provided unique code
      QuerySnapshot query = await _firestore
          .collection('exams')
          .where('examCode', isEqualTo: examCode)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw Exception('Exam not found or already closed.');
      }

      String examId = query.docs.first.id;

      // Prevent multiple joins by checking if the current student ID already exists within the active submissions
      QuerySnapshot existingSubmission = await _firestore
          .collection('exams')
          .doc(examId)
          .collection('submissions')
          .where('studentId', isEqualTo: uid)
          .limit(1)
          .get();

      if (existingSubmission.docs.isNotEmpty) {
        throw Exception('You have already joined this exam session.');
      }

      DocumentReference newSubmissionRef = _firestore
          .collection('exams')
          .doc(examId)
          .collection('submissions')
          .doc();

      // Create an initial empty submission placeholder to track live student presence
      Submission initialSubmission = Submission(
        id: newSubmissionRef.id,
        studentName: studentName,
        answers: {},
        score: 0.0,
        submittedAt: DateTime.now(),
        status: 'in_progress',
      );

      Map<String, dynamic> subData = initialSubmission.toJson();
      subData['joinedAt'] = FieldValue.serverTimestamp();
      subData['studentId'] = uid; // Store student ID for future validation

      await newSubmissionRef.set(subData);

      return {
        'examId': examId,
        'submissionId': newSubmissionRef.id,
      };
    } catch (e) {
      throw Exception('Failed to join exam: $e');
    }
  }

  // Finalizes the student's submission and performs automatic server-side grading
  Future<void> submitExamAndGrade(String examId, String submissionId, Map<String, dynamic> studentAnswers, String examType) async {
    try {
      double finalScore = 0.0;

      // Automatically calculate the score exclusively for multiple choice formats
      if (examType == 'multiple_choice') {
        QuerySnapshot questionsSnapshot = await _firestore
            .collection('exams')
            .doc(examId)
            .collection('questions')
            .get();

        int totalQuestions = questionsSnapshot.docs.length;
        int correctAnswersCount = 0;

        for (var doc in questionsSnapshot.docs) {
          Question q = Question.fromJson(doc.data() as Map<String, dynamic>, doc.id);
          // Increment score if the student's recorded answer aligns with the correct index
          if (studentAnswers.containsKey(q.id) && studentAnswers[q.id] == q.correctIndex) {
            correctAnswersCount++;
          }
        }

        finalScore = totalQuestions > 0 ? (correctAnswersCount / totalQuestions) * 100 : 0.0;
      }

      // Update the existing submission placeholder with the finalized answers and calculated score
      await _firestore
          .collection('exams')
          .doc(examId)
          .collection('submissions')
          .doc(submissionId)
          .update({
        'answers': studentAnswers,
        'score': finalScore,
        'status': 'submitted',
        'submittedAt': FieldValue.serverTimestamp(),
      });

    } catch (e) {
      throw Exception('Failed to submit and grade exam: $e');
    }
  }
}