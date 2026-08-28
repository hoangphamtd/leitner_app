/// Bộ từ vựng mẫu gồm 15 từ thông dụng.
///
/// Dùng để mồi thư viện ở lần chạy đầu tiên, và để thử giao diện khi chưa có bộ
/// 3500 từ chính thức. Định dạng cố ý giữ đúng cấu trúc mà
/// `VocabularyImporter` nhận vào — nhờ vậy dữ liệu mẫu và bộ từ vựng thật đi
/// chung một đường nạp, không cần hai nhánh xử lý riêng.
///
/// Mỗi mục chỉ có 5 trường nội dung. Các trường quản trị (mã thẻ, hộp, ngày ôn,
/// trạng thái kích hoạt) do trình nạp tự điền, vì thẻ mới nạp phải nằm im trong
/// thư viện chờ người học chủ động kích hoạt.
const List<Map<String, dynamic>> sampleVocabulary = [
  {
    'word': 'appointment',
    'phonetic': '/əˈpɔɪntmənt/',
    'meaning': 'cuộc hẹn, lịch hẹn',
    'exampleSentence':
        'I had to reschedule my dental appointment because an urgent meeting '
        'came up at work that same afternoon.',
    'imagePath': null,
  },
  {
    'word': 'grocery',
    'phonetic': '/ˈɡroʊsəri/',
    'meaning': 'hàng tạp hoá, thực phẩm',
    'exampleSentence':
        'She stopped by the grocery store on her way home to pick up some milk, '
        'eggs and a loaf of bread for breakfast.',
    'imagePath': null,
  },
  {
    'word': 'commute',
    'phonetic': '/kəˈmjuːt/',
    'meaning': 'đi lại giữa nhà và nơi làm việc',
    'exampleSentence':
        'His daily commute takes almost an hour each way, so he usually listens '
        'to podcasts to make the time pass faster.',
    'imagePath': null,
  },
  {
    'word': 'borrow',
    'phonetic': '/ˈbɑːroʊ/',
    'meaning': 'mượn',
    'exampleSentence':
        'Can I borrow your umbrella for the afternoon? I forgot mine at home and '
        'the sky looks like it is about to rain.',
    'imagePath': null,
  },
  {
    'word': 'neighbour',
    'phonetic': '/ˈneɪbər/',
    'meaning': 'hàng xóm',
    'exampleSentence':
        'Our new neighbour brought over a plate of homemade cookies the day '
        'after she moved into the apartment next door.',
    'imagePath': null,
  },
  {
    'word': 'receipt',
    'phonetic': '/rɪˈsiːt/',
    'meaning': 'hoá đơn, biên lai',
    'exampleSentence':
        'Please keep the receipt in case you want to return the shirt, because '
        'the shop will not accept it without proof of purchase.',
    'imagePath': null,
  },
  {
    'word': 'schedule',
    'phonetic': '/ˈskedʒuːl/',
    'meaning': 'lịch trình, thời gian biểu',
    'exampleSentence':
        'My schedule is completely full until Thursday, but I could meet you for '
        'coffee on Friday morning if that works for you.',
    'imagePath': null,
  },
  {
    'word': 'afford',
    'phonetic': '/əˈfɔːrd/',
    'meaning': 'đủ tiền để mua, kham nổi',
    'exampleSentence':
        'We cannot really afford a new car this year, so we decided to repair the '
        'old one and save the money instead.',
    'imagePath': null,
  },
  {
    'word': 'complain',
    'phonetic': '/kəmˈpleɪn/',
    'meaning': 'phàn nàn, khiếu nại',
    'exampleSentence':
        'Several guests complained about the noise from the construction site, so '
        'the hotel offered them a discount on their rooms.',
    'imagePath': null,
  },
  {
    'word': 'improve',
    'phonetic': '/ɪmˈpruːv/',
    'meaning': 'cải thiện, tiến bộ',
    'exampleSentence':
        'Her pronunciation has improved a lot since she started practising with a '
        'recording of herself every single evening.',
    'imagePath': null,
  },
  {
    'word': 'available',
    'phonetic': '/əˈveɪləbl/',
    'meaning': 'có sẵn, rảnh',
    'exampleSentence':
        'The doctor is not available this morning, but there is an open slot at '
        'four o clock tomorrow afternoon if you can come then.',
    'imagePath': null,
  },
  {
    'word': 'deadline',
    'phonetic': '/ˈdedlaɪn/',
    'meaning': 'hạn chót',
    'exampleSentence':
        'The deadline for submitting the report is Friday at noon, so I plan to '
        'finish the last section tonight and review it in the morning.',
    'imagePath': null,
  },
  {
    'word': 'refund',
    'phonetic': '/ˈriːfʌnd/',
    'meaning': 'hoàn tiền',
    'exampleSentence':
        'After the flight was cancelled, the airline promised a full refund, but '
        'the money only appeared in my account three weeks later.',
    'imagePath': null,
  },
  {
    'word': 'recommend',
    'phonetic': '/ˌrekəˈmend/',
    'meaning': 'giới thiệu, khuyên dùng',
    'exampleSentence':
        'A colleague recommended this little restaurant near the station, and the '
        'noodles there turned out to be even better than I expected.',
    'imagePath': null,
  },
  {
    'word': 'weather',
    'phonetic': '/ˈweðər/',
    'meaning': 'thời tiết',
    'exampleSentence':
        'The weather has been unusually cold this week, so remember to bring a '
        'jacket if you are going out early in the morning.',
    'imagePath': null,
  },
];
