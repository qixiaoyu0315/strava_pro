import 'package:strava_client/strava_client.dart';
import '../service/strava_service.dart';

class StravaClientManager {
  static final StravaClientManager _instance = StravaClientManager._internal();
  late StravaClient stravaClient;

  factory StravaClientManager() {
    return _instance;
  }

  StravaClientManager._internal();

  Future<void> initialize(String clientId, String secret) async {
    stravaClient = StravaClient(clientId: clientId, secret: secret);
    // 进行认证逻辑
  }

  Future<TokenResponse> authenticate() async {
    return await ExampleAuthentication(stravaClient).testAuthentication(
      [
        AuthenticationScope.profile_read_all,
        AuthenticationScope.read_all,
        AuthenticationScope.activity_read_all
      ],
      "stravaflutter://redirect",
    );
  }
} 