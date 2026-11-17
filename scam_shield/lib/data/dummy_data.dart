// ---------------------------------------------------------------------------
// PHASE 3: demo data is GONE - checks now come from the real ScamEngine
// (lib/engine/) and live in HistoryStore (lib/state/).
//
// What remains is [scamTypes]: real educational content for the Learn tab,
// not a placeholder.
// ---------------------------------------------------------------------------

/// One entry of the Pattern Library (Learn tab) - real content for parents.
class ScamType {
  final int number;
  final String title;
  final String example;
  final String wants;
  final String advice;

  const ScamType({
    required this.number,
    required this.title,
    required this.example,
    required this.wants,
    required this.advice,
  });
}

const scamTypes = <ScamType>[
  ScamType(
    number: 1,
    title: 'Bank / KYC / PAN Expiry',
    example: '"Your SBI KYC/PAN is suspended today, update via link"',
    wants: 'Clicking a phishing link or sharing OTP/card details',
    advice:
        "Never click SMS links for KYC - open your bank's official app or "
        'visit the branch.',
  ),
  ScamType(
    number: 2,
    title: 'Electricity / Utility Cut-off',
    example: '"BESCOM power will be disconnected at 9:30 PM tonight; call officer"',
    wants: 'Calling a fake number or installing a screen-sharing app',
    advice:
        'Check your bill directly in the official state electricity portal '
        'or UPI bill-pay app.',
  ),
  ScamType(
    number: 3,
    title: 'Fake Delivery / Customs Parcel',
    example: '"India Post: Your package has an incomplete address, update within 24h"',
    wants: 'Paying a small "re-delivery fee" on a phishing page',
    advice:
        'Check live status only inside the shopping app (Amazon, Flipkart) '
        'where you ordered.',
  ),
  ScamType(
    number: 4,
    title: '"Digital Arrest" / Fake Emergency',
    example:
        '"CBI/Customs found an illegal parcel in your name" or "Dad, my phone broke, send Rs. 15k"',
    wants: 'Panic transfers before you can verify the caller',
    advice:
        'Hang up and call your family member on their saved number - police '
        'never conduct arrests on video calls.',
  ),
  ScamType(
    number: 5,
    title: 'Fake UPI Credit / Collect Trap',
    example: '"Rs. 25,000 credited to your A/c in error" or "Enter UPI PIN to receive refund"',
    wants: 'Tricking you into entering your UPI PIN on a Collect Request',
    advice:
        'Golden rule: you never enter a UPI PIN to receive money - only to '
        'send it.',
  ),
  ScamType(
    number: 6,
    title: 'Pre-Approved Loan / Job / Lottery',
    example: '"Instant Rs. 5 Lakh loan, 0% interest, download app" or "Earn Rs. 5,000/day liking videos"',
    wants: 'Paying "processing fees" or installing predatory loan .apk files',
    advice:
        'Ignore unsolicited loan or job offers - never install .apk files '
        'sent via SMS or chat.',
  ),
];
