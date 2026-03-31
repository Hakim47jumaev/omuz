import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import 'resume_pdf_save.dart';

class ResumeRepository {
  final _dio = ApiClient().dio;

  Future<Map<String, dynamic>> getChoices() async {
    final res = await _dio.get(Endpoints.resumeChoices);
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getResumes() async {
    final res = await _dio.get(Endpoints.resumes);
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getResume(int id) async {
    final res = await _dio.get(Endpoints.resumeDetail(id));
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createResume(Map<String, dynamic> data) async {
    final res = await _dio.post(Endpoints.resumes, data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateResume(int id, Map<String, dynamic> data) async {
    final res = await _dio.put(Endpoints.resumeDetail(id), data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteResume(int id) async {
    await _dio.delete(Endpoints.resumeDetail(id));
  }

  Future<String> downloadPdf(int id) async {
    final res = await _dio.get(
      Endpoints.resumeDownload(id),
      options: Options(responseType: ResponseType.bytes),
    );
    final raw = res.data;
    final bytes = raw is Uint8List
        ? raw
        : Uint8List.fromList(List<int>.from(raw as List));
    return saveResumePdf(bytes, id);
  }

  Future<List<dynamic>> getUsersForAdminResume() async {
    final res = await _dio.get(Endpoints.adminTopup);
    return res.data as List<dynamic>;
  }
}
