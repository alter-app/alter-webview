import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../data/webview_bridge.dart';
import '../../../config/app_config.dart';

class WebViewScreen extends ConsumerStatefulWidget {
  const WebViewScreen({super.key});

  @override
  ConsumerState<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends ConsumerState<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _error;
  bool _bridgeSetup = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(false)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // 로딩 진행률 업데이트
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _error = null;
            });
          },
          onPageFinished: (String url) async {
            setState(() {
              _isLoading = false;
            });
            
            // WebView 초기화 완료 후 브릿지 설정
            await _setupWebViewBridge();
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
              _error = error.description;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            // 모든 네비게이션 허용
            return NavigationDecision.navigate;
          },
        ),
      );
    
    // JavaScript 채널을 먼저 설정
    _setupJavaScriptChannels();
    
    // 그 다음 URL 로드
    _controller.loadRequest(Uri.parse(AppConfig.webUrl));
  }
  
  void _setupJavaScriptChannels() {
    try {
      final bridge = WebViewBridge(_controller, ref, context);
      bridge.setupJavaScriptChannels();
    } catch (e) {
      // JavaScript 채널 설정 실패 시 무시
    }
  }

  Future<void> _setupWebViewBridge() async {
    // 이미 브릿지가 설정되었다면 중복 실행 방지
    if (_bridgeSetup) return;
    
    try {
      final bridge = WebViewBridge(_controller, ref, context);
      
      // 토큰 주입
      await bridge.injectToken();
      
      // 네이티브 데이터 주입
      await bridge.injectNativeData();
      
      _bridgeSetup = true;
    } catch (e) {
      setState(() {
        _error = '브릿지 설정 실패: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
          if (_error != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '오류가 발생했습니다',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _controller.reload();
                    },
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

}

