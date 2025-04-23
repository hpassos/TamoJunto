import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_contact/flutter_contact.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TamoJunto',
      home: PhoneLoginPage(),
    );
  }
}

class PhoneLoginPage extends StatefulWidget {
  @override
  _PhoneLoginPageState createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;
  List<Contact> _contacts = [];
  List<Contact> _notInApp = [];

  void _signInWithPhone() async {
    final phone = _phoneController.text.trim();
    await Supabase.instance.client.auth.signInWithOtp(phone: phone);
    setState(() => _otpSent = true);
  }

  void _verifyOtp() async {
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();
    await Supabase.instance.client.auth.verifyOTP(
      phone: phone,
      token: otp,
      type: OtpType.sms,
    );
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    if (await Permission.contacts.request().isGranted) {
      final contacts = await FlutterContact.getContacts(withProperties: true);
      final appUsers = await Supabase.instance.client
          .from('profiles')
          .select('phone')
          .execute();
      final registeredPhones =
          List<String>.from(appUsers.data.map((u) => u['phone']));

      setState(() {
        _contacts = contacts;
        _notInApp = contacts.where((c) {
          final phone = c.phones.isNotEmpty ? c.phones.first.normalizedNumber : '';
          return phone.isNotEmpty && !registeredPhones.contains(phone);
        }).toList();
      });
    }
  }

  void _sendInvite(Contact contact) async {
    final phone = contact.phones.first.normalizedNumber;
    final message = Uri.encodeComponent("Ei! Estou usando o TamoJunto para organizar jogos e campeonatos. Entra lá: https://TamoJunto.app");
    final link = Uri.parse("https://wa.me/$phone?text=$message");
    if (await canLaunchUrl(link)) {
      await launchUrl(link);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Entrar com Telefone')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(labelText: 'Número de telefone'),
              keyboardType: TextInputType.phone,
            ),
            if (_otpSent)
              TextField(
                controller: _otpController,
                decoration: InputDecoration(labelText: 'Código recebido'),
                keyboardType: TextInputType.number,
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _otpSent ? _verifyOtp : _signInWithPhone,
              child: Text(_otpSent ? 'Verificar Código' : 'Enviar Código'),
            ),
            if (_notInApp.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _notInApp.length,
                  itemBuilder: (context, index) {
                    final contact = _notInApp[index];
                    return ListTile(
                      title: Text(contact.displayName),
                      subtitle: Text(contact.phones.first.normalizedNumber),
                      trailing: IconButton(
                        icon: Icon(Icons.send),
                        onPressed: () => _sendInvite(contact),
                      ),
                    );
                  },
                ),
              )
          ],
        ),
      ),
    );
  }
}
