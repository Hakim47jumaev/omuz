import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';

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
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/resume_$id.pdf';
    await _dio.download(
      Endpoints.resumeDownload(id),
      path,
      options: Options(responseType: ResponseType.bytes),
    );
    return path;
  }

  Future<List<dynamic>> getUsersForAdminResume() async {
    final res = await _dio.get(Endpoints.adminTopup);
    return res.data as List<dynamic>;
  }
}
