import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:hostify/legacy/screens/auth_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  bool _isLastPage = false;

  final List<OnboardingData> _onboardingPages = [
    OnboardingData(
      title: 'Welcome to .Hostify',
      description: 'Your premium destination for luxury stays and seamless management.',
      icon: Icons.hotel_rounded,
    ),
    OnboardingData(
      title: 'Seamless Booking',
      description: 'Book your stay with ease and manage your reservations in one place.',
      icon: Icons.calendar_month_rounded,
    ),
    OnboardingData(
      title: 'Manage Your Property',
      description: 'Are you a landlord? Manage your properties and track earnings effortlessly.',
      icon: Icons.dashboard_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Pattern or Subtle Logo
          Positioned(
            top: -100,
            right: -100,
            child: Opacity(
              opacity: 0.05,
              child: Image.asset(
                'assets/images/hostifylogo.png',
                width: 400,
                height: 400,
                color: Colors.black.withOpacity(0.05),
              ),
            ),
          ),

          // Content
          Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _isLastPage = index == _onboardingPages.length - 1;
                    });
                  },
                  itemCount: _onboardingPages.length,
                  itemBuilder: (context, index) {
                    return OnboardingPageWidget(data: _onboardingPages[index]);
                  },
                ),
              ),

              // Bottom Area
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 60),
                child: Column(
                  children: [
                    // Indicator
                    SmoothPageIndicator(
                      controller: _pageController,
                      count: _onboardingPages.length,
                      effect: const ExpandingDotsEffect(
                        activeDotColor: Colors.black,
                        dotColor: Colors.black26,
                        dotHeight: 8,
                        dotWidth: 8,
                        expansionFactor: 4,
                        spacing: 8,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Action Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const AuthScreen()),
                            );
                          },
                          child: Text(
                            'SKIP',
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.6),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            if (_isLastPage) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const AuthScreen()),
                              );
                            } else {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            _isLastPage ? 'GET STARTED' : 'NEXT',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String description;
  final IconData icon;

  OnboardingData({
    required this.title,
    required this.description,
    required this.icon,
  });
}

class OnboardingPageWidget extends StatelessWidget {
  final OnboardingData data;

  const OnboardingPageWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon Container
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              data.icon,
              size: 100,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 60),

          // Text
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(height: 24),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withOpacity(0.7),
              fontSize: 16,
              height: 1.5,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    );
  }
}
