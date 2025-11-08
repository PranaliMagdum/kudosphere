import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const KudosphereApp());
}

class KudosphereApp extends StatelessWidget {
  const KudosphereApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kudosphere',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          print("🔄 Auth state: ${snapshot.connectionState}");
          print("👤 Has user: ${snapshot.hasData}");

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFFFF9B7D)),
              ),
            );
          }

          if (snapshot.hasData) {
            print("✅ User logged in, showing HomePage");
            return const HomePage();
          }

          print("❌ No user, showing AuthPage");
          return const AuthPage();
        },
      ),
      routes: {
        '/home': (_) => const HomePage(),
        '/recognize': (_) => const RecognizePage(),
        '/redeem': (_) => const RedeemRewardsPage(),
        '/cart': (_) => const CartPage(),
        '/history': (_) => const RewardsHistoryPage(),
      },
    );
  }
}


// LOGIN & REGISTER PAGE
class AuthPage extends StatefulWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool isLogin = true;
  final emailCtrl = TextEditingController();
  final pwdCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  bool _isLoading = false;

  void _toggleForm() {
    setState(() {
      isLogin = !isLogin;
    });
  }

  Future<void> _submit() async {
    // Don't proceed if already loading
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      if (isLogin) {
        // Login with timeout
        await FirebaseAuth.instance
            .signInWithEmailAndPassword(
          email: emailCtrl.text.trim(),
          password: pwdCtrl.text,
        )
            .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Login timeout - check your internet connection');
          },
        );

        print("✅ Login successful!");

      } else {
        // Register with timeout
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: emailCtrl.text.trim(),
          password: pwdCtrl.text,
        )
            .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Registration timeout - check your internet connection');
          },
        );

        print("✅ Registration successful, creating user document...");

        // Create user document in Firestore with timeout
        await FirebaseFirestore.instance
            .collection('users')
            .doc(credential.user!.uid)
            .set({
          'name': nameCtrl.text.trim(),
          'email': emailCtrl.text.trim(),
          'points': 3000,
          'createdAt': FieldValue.serverTimestamp(),
        }).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print("⚠️ User document creation timeout, will create on first login");
          },
        );

        print("✅ User document created!");
      }

      // Authentication succeeded - StreamBuilder will handle navigation automatically
      print("🎉 Auth complete - waiting for StreamBuilder navigation...");

    } catch (e) {
      print("❌ Auth error: $e");

      if (mounted) {
        setState(() => _isLoading = false);

        String errorMessage = 'Login failed';

        if (e.toString().contains('user-not-found')) {
          errorMessage = 'No account found with this email';
        } else if (e.toString().contains('wrong-password')) {
          errorMessage = 'Incorrect password';
        } else if (e.toString().contains('email-already-in-use')) {
          errorMessage = 'Email already registered - try logging in';
        } else if (e.toString().contains('weak-password')) {
          errorMessage = 'Password must be at least 6 characters';
        } else if (e.toString().contains('invalid-email')) {
          errorMessage = 'Invalid email format';
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network error - check your internet connection';
        } else if (e.toString().contains('timeout')) {
          errorMessage = e.toString().replaceAll('Exception:', '');
        } else {
          errorMessage = e.toString();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFE5D9), Color(0xFFFFD4C1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
        child: Column(
          children: [
            const Text(
              "Kudosphere",
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF9B7D),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isLogin ? "Welcome Back 👋" : "Create Account",
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: Color(0xFF495057)),
            ),
            const SizedBox(height: 40),
            if (!isLogin)
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: "Name",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
              ),
            if (!isLogin) const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: "Email",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pwdCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 40),
            _isLoading
                ? const CircularProgressIndicator(color: Color(0xFFFF9B7D))
                : ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: const Color(0xFFFF9B7D),
              ),
              onPressed: _submit,
              child: Text(
                isLogin ? "Login" : "Register",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _toggleForm,
              child: Text(
                isLogin ? "Don't have an account? Register" : "Already have an account? Login",
                style: const TextStyle(color: Color(0xFFFF9B7D), fontWeight: FontWeight.w500),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// HOME PAGE
class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String userName = "User";
  int userPoints = 3000;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          userName = data['name'] ?? user.email?.split('@') ?? 'User';
          userPoints = data['points'] ?? 3000;
        });
      }
    } catch (e) {
      print("Error loading user data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF9B7D),
        title: Text("Hi, $userName! 👋", style: const TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFE5D9), Color(0xFFFFF8F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFFF9B7D).withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Your Balance:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  Text("$userPoints points", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFFF9B7D))),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FeatureCard(
              icon: Icons.handshake,
              color: const Color(0xFFFFB399),
              text: "Give a Kudo",
              onTap: () => Navigator.pushNamed(context, '/recognize').then((_) => _loadUserData()),
            ),
            FeatureCard(
              icon: Icons.workspace_premium,
              color: const Color(0xFFFF9B7D),
              text: "Redeem Rewards",
              onTap: () => Navigator.pushNamed(context, '/redeem').then((_) => _loadUserData()),
            ),
            FeatureCard(
              icon: Icons.history,
              color: const Color(0xFFFFCBB3),
              text: "Recognition History",
              onTap: () => Navigator.pushNamed(context, '/history'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFF9B7D),
        tooltip: "Give Quick Kudo",
        child: const Icon(Icons.thumb_up_alt_outlined, color: Colors.white),
        onPressed: () => Navigator.pushNamed(context, '/recognize').then((_) => _loadUserData()),
      ),
    );
  }
}

class FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback onTap;

  const FeatureCard({
    Key? key,
    required this.icon,
    required this.color,
    required this.text,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFF8F5),
      shadowColor: color.withOpacity(0.4),
      elevation: 6,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(icon, color: color, size: 34),
        title: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF495057))),
        trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFFFF9B7D)),
        onTap: onTap,
      ),
    );
  }
}

// RECOGNIZE PAGE
class RecognizePage extends StatefulWidget {
  const RecognizePage({Key? key}) : super(key: key);

  @override
  State<RecognizePage> createState() => _RecognizePageState();
}

class _RecognizePageState extends State<RecognizePage> {
  int step = 0;
  String recipient = '';
  String level = '';
  String message = '';
  final List<String> levels = ['👏 Clap (10)', '🚀 Superstar (50)', '🏆 Legend (100)'];
  late ConfettiController _confettiController;
  final TextEditingController recipientController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    recipientController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _sendRecognition() async {
    final points = level.contains('10') ? 10 : (level.contains('50') ? 50 : 100);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('recognitions').add({
        'senderId': user.uid,
        'senderEmail': user.email,
        'recipient': recipient,
        'level': level,
        'points': points,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _confettiController.play();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Kudo sent to $recipient! 🎉"), backgroundColor: const Color(0xFFFF9B7D)),
        );
      }

      setState(() {
        recipientController.clear();
        recipient = '';
        level = '';
        message = '';
        step = 0;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Give a Kudo", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFFF9B7D),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Stepper(
            type: StepperType.vertical,
            currentStep: step,
            onStepCancel: step == 0 ? null : () => setState(() => step--),
            onStepContinue: () {
              if (step < 3) {
                if (step == 0 && recipientController.text.trim().isEmpty) {
                  _showError("Please enter a recipient name");
                  return;
                } else if (step == 1 && level.isEmpty) {
                  _showError("Please select a Kudo level");
                  return;
                } else if (step == 2 && message.trim().isEmpty) {
                  _showError("Please enter a message");
                  return;
                }
                if (step == 0) {
                  setState(() => recipient = recipientController.text.trim());
                }
                setState(() => step++);
              } else {
                _sendRecognition();
              }
            },
            controlsBuilder: (context, controls) {
              return Row(
                children: <Widget>[
                  ElevatedButton(
                    onPressed: controls.onStepContinue,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9B7D)),
                    child: Text(step == 3 ? 'Send' : 'Next', style: const TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  if (step > 0)
                    TextButton(
                      onPressed: controls.onStepCancel,
                      child: const Text('Back', style: TextStyle(color: Color(0xFFFF9B7D))),
                    ),
                ],
              );
            },
            steps: [
              Step(
                title: const Text("Enter Recipient's Name"),
                isActive: step == 0,
                state: recipient.isEmpty ? StepState.indexed : StepState.complete,
                content: TextFormField(
                  controller: recipientController,
                  decoration: const InputDecoration(
                    labelText: "Recipient Name",
                    icon: Icon(Icons.person, color: Color(0xFFFF9B7D)),
                    filled: true,
                    fillColor: Color(0xFFFFF8F5),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Step(
                title: const Text("Select Kudo Level"),
                isActive: step == 1,
                state: level.isEmpty ? StepState.indexed : StepState.complete,
                content: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: "Level",
                    icon: Icon(Icons.star, color: Color(0xFFFF9B7D)),
                    filled: true,
                    fillColor: Color(0xFFFFF8F5),
                    border: OutlineInputBorder(),
                  ),
                  items: levels.map((l) => DropdownMenuItem<String>(value: l, child: Text(l))).toList(),
                  value: level.isEmpty ? null : level,
                  onChanged: (val) => setState(() => level = val ?? ''),
                ),
              ),
              Step(
                title: const Text("Write a Message"),
                isActive: step == 2,
                state: message.isEmpty ? StepState.indexed : StepState.complete,
                content: TextFormField(
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: "Message",
                    icon: Icon(Icons.message, color: Color(0xFFFF9B7D)),
                    filled: true,
                    fillColor: Color(0xFFFFF8F5),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => setState(() => message = val),
                ),
              ),
              Step(
                title: const Text("Review & Confirm"),
                isActive: step == 3,
                state: StepState.editing,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Recipient: $recipient", style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text("Level: $level", style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text("Message: $message", style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Color(0xFFFF9B7D), Color(0xFFFFB399), Color(0xFFFFCBB3), Color(0xFFFFE5D9)],
            ),
          ),
        ],
      ),
    );
  }
}

// REDEEM REWARDS PAGE
class RedeemRewardsPage extends StatelessWidget {
  const RedeemRewardsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> giftCards = [
      {'name': 'Tim Hortons', 'price': 50, 'points': 500, 'logo': 'https://upload.wikimedia.org/wikipedia/en/thumb/d/d2/Tim_Hortons_logo.svg/200px-Tim_Hortons_logo.svg.png'},
      {'name': 'Udemy', 'price': 50, 'points': 500, 'logo': 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e3/Udemy_logo.svg/200px-Udemy_logo.svg.png'},
      {'name': 'Amazon', 'price': 50, 'points': 500, 'logo': 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a9/Amazon_logo.svg/200px-Amazon_logo.svg.png'},
      {'name': 'Coursera', 'price': 50, 'points': 500, 'logo': 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/97/Coursera-Logo_600x600.svg/200px-Coursera-Logo_600x600.svg.png'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Redeem Rewards", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFFF9B7D),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, '/cart'),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFE5D9), Color(0xFFFFF8F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 0.75,
          ),
          itemCount: giftCards.length,
          itemBuilder: (context, index) {
            final card = giftCards[index];
            return GiftCardItem(card: card);
          },
        ),
      ),
    );
  }
}

class GiftCardItem extends StatelessWidget {
  final Map<String, dynamic> card;

  const GiftCardItem({Key? key, required this.card}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Image.network(card['logo'], fit: BoxFit.contain),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF8F5),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                Text(
                  card['name'],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text("\$${card['price']}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text("${card['points']} Points", style: const TextStyle(fontSize: 12, color: Color(0xFFFF9B7D))),
                const SizedBox(height: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9B7D),
                    minimumSize: const Size(double.infinity, 36),
                  ),
                  onPressed: () {
                    CartService.addToCart(card);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("${card['name']} added to cart!"),
                        backgroundColor: const Color(0xFFFF9B7D),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: const Text("Add to Cart", style: TextStyle(fontSize: 12, color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// CART SERVICE
class CartService {
  static final List<Map<String, dynamic>> _cart = [];

  static List<Map<String, dynamic>> get cart => _cart;

  static void addToCart(Map<String, dynamic> item) {
    final existing = _cart.firstWhere(
          (cartItem) => cartItem['name'] == item['name'],
      orElse: () => {},
    );

    if (existing.isNotEmpty) {
      existing['quantity'] = (existing['quantity'] ?? 1) + 1;
    } else {
      _cart.add({...item, 'quantity': 1});
    }
  }

  static void removeFromCart(Map<String, dynamic> item) {
    _cart.remove(item);
  }

  static void updateQuantity(Map<String, dynamic> item, int quantity) {
    if (quantity <= 0) {
      removeFromCart(item);
    } else {
      item['quantity'] = quantity;
    }
  }

  static void clearCart() {
    _cart.clear();
  }

  static int getTotalPoints() {
    return _cart.fold<int>(0, (sum, item) => sum + ((item['points'] as int) * (item['quantity'] as int)));
  }
}

// CART PAGE
class CartPage extends StatefulWidget {
  const CartPage({Key? key}) : super(key: key);

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _checkout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final totalPoints = CartService.getTotalPoints();

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userPoints = userDoc.data()?['points'] ?? 0;

      if (totalPoints > userPoints) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Insufficient points!"), backgroundColor: Colors.red),
          );
        }
        return;
      }

      for (var item in CartService.cart) {
        await FirebaseFirestore.instance.collection('redemptions').add({
          'userId': user.uid,
          'giftCardName': item['name'],
          'price': item['price'],
          'points': item['points'] * item['quantity'],
          'quantity': item['quantity'],
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'points': FieldValue.increment(-totalPoints),
      });

      _confettiController.play();
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Success! 🎉"),
            content: const Text("Your gift cards have been redeemed!"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }

      CartService.clearCart();
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartService.cart;
    final totalPoints = CartService.getTotalPoints();

    return Scaffold(
      appBar: AppBar(
        title: Text("My Cart (${cart.length})", style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFFF9B7D),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          cart.isEmpty
              ? const Center(
            child: Text("Your cart is empty", style: TextStyle(fontSize: 18, color: Colors.grey)),
          )
              : Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cart.length,
                  itemBuilder: (context, index) {
                    final item = cart[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Image.network(item['logo'], width: 50, height: 50, fit: BoxFit.contain),
                        title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("${item['points']} points × ${item['quantity']}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: Color(0xFFFF9B7D)),
                              onPressed: () {
                                setState(() {
                                  CartService.updateQuantity(item, item['quantity'] - 1);
                                });
                              },
                            ),
                            Text("${item['quantity']}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle, color: Color(0xFFFF9B7D)),
                              onPressed: () {
                                setState(() {
                                  CartService.updateQuantity(item, item['quantity'] + 1);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Total Points:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text("$totalPoints", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFFF9B7D))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9B7D),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: _checkout,
                      child: const Text("Checkout", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Color(0xFFFF9B7D), Color(0xFFFFB399), Color(0xFFFFCBB3)],
            ),
          ),
        ],
      ),
    );
  }
}

// REWARDS HISTORY PAGE
class RewardsHistoryPage extends StatelessWidget {
  const RewardsHistoryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("History", style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFFFF9B7D),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Color(0xFFFFD4C1),
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "Recognitions Given"),
              Tab(text: "Rewards Redeemed"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('recognitions')
                  .where('senderId', isEqualTo: user?.uid)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No recognitions yet"));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.emoji_events, color: Color(0xFFFF9B7D), size: 40),
                        title: Text("To: ${data['recipient']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("${data['level']}\n${data['message']}", maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: Text("${data['points']} pts", style: const TextStyle(color: Color(0xFFFF9B7D), fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                );
              },
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('redemptions')
                  .where('userId', isEqualTo: user?.uid)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No redemptions yet"));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.card_giftcard, color: Color(0xFFFF9B7D), size: 40),
                        title: Text(data['giftCardName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Quantity: ${data['quantity']}"),
                        trailing: Text("-${data['points']} pts", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}