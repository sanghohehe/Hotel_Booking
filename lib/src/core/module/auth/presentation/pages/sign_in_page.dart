import 'package:booking_app/src/core/module/auth/presentation/pages/widget/textFieldWidget.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:ui_kit/supabase/supabase_manager.dart'; // Đảm bảo đúng path

// --- CÁC IMPORT CŨ CỦA BẠN (GIỮ NGUYÊN) ---
import '../../../../supabase/supabase_manager.dart';
import '../../../home/presentation/pages/main_shell_page.dart';
import '../../../admin/presentation/pages/admin_home_page.dart';
import '../../../admin/admin_config.dart';
import 'sign_up_page.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscureText = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- LOGIC SUPABASE CỦA BẠN (GIỮ NGUYÊN) ---
  Future<void> _onSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final client = SupabaseManager.client;
      final response = await client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final user = response.user;
      if (user == null) throw Exception('Không nhận được thông tin user');
      final email = user.email ?? '';
      final admin = isAdminEmail(email);
      if (!mounted) return;
      if (admin) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => AdminHomePage(email: email)),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => MainShellPage(email: email)),
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi đăng nhập: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Với Hotel App, màu chính thường là Nâu đất, Vàng kim nhạt, hoặc Xanh Teal sang trọng.
    // Giả sử màu primary của bạn là xanh Teal:
    final primaryColor = Colors.teal;

    return Scaffold(
      body: Stack(
        children: [
          // 1. LỚP NỀN: HÌNH ẢNH KHÁCH SẠN
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                  'assets/images/hotel_bg.jpg',
                ), // Path tới ảnh của bạn
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 2. LỚP PHỦ (OVERLAY): Giúp Form nổi bật và dễ đọc
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.2), // Trên mờ nhẹ
                  Colors.black.withOpacity(
                    0.7,
                  ), // Dưới mờ đậm hơn để nổi bật form trắng
                ],
              ),
            ),
          ),

          // 3. LỚP NỘI DUNG (NÊN SỬ DỤNG PANEL TRẮNG PHÍA DƯỚI)
          SafeArea(
            child: Column(
              children: [
                // Phần trên: Logo hoặc Slogan nhạt
                const SizedBox(height: 40),
                Center(
                  child: Icon(
                    Icons.hotel_class_rounded,
                    size: 60,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your Luxury Stay Awaits',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(), // Đẩy form xuống dưới
                // Phần dưới: Form đăng nhập (Nên dùng panel trắng để tương phản)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đăng nhập 👋',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Email Field (Sử dụng hàm build đã sạch ở câu trước)
                        CustomTextField(
                          controller: _emailController,
                          label: 'Email Address',
                          hint: 'example@gmail.com',
                          icon: Icons.email_outlined,
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Vui lòng nhập email';
                            if (!value.contains('@'))
                              return 'Email không hợp lệ';
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Password Field
                        CustomTextField(
                          controller: _passwordController,
                          label: 'Password',
                          hint: '••••••••',
                          icon: Icons.lock_outline_rounded,
                          isPassword: true,
                          obscureText: _obscureText,
                          onSuffixIconPressed:
                              () =>
                                  setState(() => _obscureText = !_obscureText),
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Vui lòng nhập mật khẩu';
                            return null;
                          },
                        ),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {},
                            child: const Text('Quên mật khẩu?'),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Login Button (Dùng màu Teal sang trọng)
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _onSignIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 2,
                            ),
                            child:
                                _loading
                                    ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                    : const Text(
                                      'ĐĂNG NHẬP',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                          ),
                        ),

                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Chưa có tài khoản?",
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            TextButton(
                              onPressed:
                                  () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const SignUpPage(),
                                    ),
                                  ),
                              child: const Text(
                                'Đăng ký ngay',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16), // Thêm chút space ở dưới
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
