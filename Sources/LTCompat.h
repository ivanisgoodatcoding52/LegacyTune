#ifndef LTCompat_h
#define LTCompat_h

// UITextAlignment (Center/Right/Left) was deprecated in favor of
// NSTextAlignment starting iOS 6.0 — but NSTextAlignmentCenter etc.
// don't exist as symbols in pre-iOS-6 SDKs (Tier A compiles against
// iPhoneOS4.3). Since Sources/ is shared between Tier A and Tier B,
// neither the old nor the new named constant works cleanly across both:
// the old one triggers a deprecation-as-error on Tier B's iOS 6.1 SDK
// (confirmed from an actual build failure earlier in this project, for
// a different deprecated API), and the new one doesn't exist at all on
// Tier A's SDK. UITextAlignment and NSTextAlignment use IDENTICAL
// underlying integer values — a deliberate, binary-compatible rename,
// not a real behavior change — so plain integer literals here are
// exactly as correct as either named constant, and sidestep the
// cross-tier problem entirely.
#define LTTextAlignmentLeft   0
#define LTTextAlignmentCenter 1
#define LTTextAlignmentRight  2

#endif
