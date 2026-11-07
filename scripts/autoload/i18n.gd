extends Node
## Çok dilli metin kaynağı. Metinler görsellere gömülmez; buradan okunur.
## Diller: tr, en, ru, uz, zh, ko. Anahtar bulunamazsa İngilizce, o da yoksa anahtarın kendisi döner.

signal language_changed

const LANGS: Array[String] = ["tr", "en", "ru", "uz", "zh", "ko"]
const LANG_NAMES := {
	"tr": "Türkçe", "en": "English", "ru": "Русский",
	"uz": "Oʻzbekcha", "zh": "中文", "ko": "한국어",
}

var lang: String = "en"

const S := {
	"app_title": {"tr": "Penaltı Ustası", "en": "Penalty Master", "ru": "Мастер пенальти", "uz": "Penalti ustasi", "zh": "点球大师", "ko": "페널티 마스터"},
	"tagline": {"tr": "Kaleci seni okuyor!", "en": "The keeper is reading you!", "ru": "Вратарь читает тебя!", "uz": "Darvozabon sizni oʻqiyapti!", "zh": "门将在读你！", "ko": "골키퍼가 당신을 읽고 있다!"},
	"play": {"tr": "Oyna", "en": "Play", "ru": "Играть", "uz": "Oʻynash", "zh": "开始", "ko": "플레이"},
	"campaign": {"tr": "Kariyer", "en": "Career", "ru": "Карьера", "uz": "Martaba", "zh": "生涯", "ko": "커리어"},
	"quick_match": {"tr": "Hızlı maç", "en": "Quick match", "ru": "Быстрый матч", "uz": "Tezkor oʻyin", "zh": "快速比赛", "ko": "빠른 경기"},
	"kits": {"tr": "Formalar", "en": "Kits", "ru": "Форма", "uz": "Formalar", "zh": "球衣", "ko": "유니폼"},
	"shop": {"tr": "Mağaza", "en": "Shop", "ru": "Магазин", "uz": "Doʻkon", "zh": "商店", "ko": "상점"},
	"settings": {"tr": "Ayarlar", "en": "Settings", "ru": "Настройки", "uz": "Sozlamalar", "zh": "设置", "ko": "설정"},
	"how_to_play": {"tr": "Nasıl oynanır?", "en": "How to play", "ru": "Как играть", "uz": "Qanday oʻynaladi?", "zh": "玩法", "ko": "플레이 방법"},
	"about": {"tr": "Hakkında", "en": "About", "ru": "Об игре", "uz": "Haqida", "zh": "关于", "ko": "정보"},
	"back": {"tr": "Geri", "en": "Back", "ru": "Назад", "uz": "Orqaga", "zh": "返回", "ko": "뒤로"},
	"close": {"tr": "Kapat", "en": "Close", "ru": "Закрыть", "uz": "Yopish", "zh": "关闭", "ko": "닫기"},
	"cancel": {"tr": "Vazgeç", "en": "Cancel", "ru": "Отмена", "uz": "Bekor qilish", "zh": "取消", "ko": "취소"},
	"ok": {"tr": "Tamam", "en": "OK", "ru": "ОК", "uz": "Mayli", "zh": "好的", "ko": "확인"},
	"exit_q": {"tr": "Oyundan çıkılsın mı?", "en": "Quit the game?", "ru": "Выйти из игры?", "uz": "Oʻyindan chiqilsinmi?", "zh": "退出游戏？", "ko": "게임을 종료할까요?"},
	"exit": {"tr": "Çık", "en": "Quit", "ru": "Выйти", "uz": "Chiqish", "zh": "退出", "ko": "종료"},
	"your_kit": {"tr": "Senin formanın", "en": "Your kit", "ru": "Твоя форма", "uz": "Sizning formangiz", "zh": "你的球衣", "ko": "내 유니폼"},
	"rival_kit": {"tr": "Yapay zekâ forması", "en": "AI kit", "ru": "Форма ИИ", "uz": "SI formasi", "zh": "AI 球衣", "ko": "AI 유니폼"},
	"kit_red_yellow": {"tr": "Sarı-Kırmızı", "en": "Yellow-Red", "ru": "Жёлто-красные", "uz": "Sariq-qizil", "zh": "黄红", "ko": "노랑-빨강"},
	"kit_yellow_navy": {"tr": "Sarı-Lacivert", "en": "Yellow-Navy", "ru": "Жёлто-синие", "uz": "Sariq-toʻq koʻk", "zh": "黄藏青", "ko": "노랑-네이비"},
	"kit_black_white": {"tr": "Siyah-Beyaz", "en": "Black-White", "ru": "Чёрно-белые", "uz": "Qora-oq", "zh": "黑白", "ko": "흑백"},
	"kit_claret_blue": {"tr": "Bordo-Mavi", "en": "Claret-Blue", "ru": "Бордово-голубые", "uz": "Bordo-havorang", "zh": "酒红蓝", "ko": "버건디-블루"},
	"select": {"tr": "Seç", "en": "Select", "ru": "Выбрать", "uz": "Tanlash", "zh": "选择", "ko": "선택"},
	"selected": {"tr": "Seçili", "en": "Selected", "ru": "Выбрано", "uz": "Tanlangan", "zh": "已选", "ko": "선택됨"},
	"same_kit": {"tr": "Rakip başka renk seçmeli", "en": "The rival needs different colours", "ru": "Соперник должен быть в другом цвете", "uz": "Raqib boshqa rang tanlashi kerak", "zh": "对手需选择不同颜色", "ko": "상대는 다른 색이어야 해요"},
	"difficulty": {"tr": "Zorluk", "en": "Difficulty", "ru": "Сложность", "uz": "Qiyinlik", "zh": "难度", "ko": "난이도"},
	"diff_0": {"tr": "Kolay", "en": "Easy", "ru": "Легко", "uz": "Oson", "zh": "简单", "ko": "쉬움"},
	"diff_1": {"tr": "Normal", "en": "Normal", "ru": "Нормально", "uz": "Oddiy", "zh": "普通", "ko": "보통"},
	"diff_2": {"tr": "Zor", "en": "Hard", "ru": "Сложно", "uz": "Qiyin", "zh": "困难", "ko": "어려움"},
	"diff_3": {"tr": "Efsane", "en": "Legend", "ru": "Легенда", "uz": "Afsona", "zh": "传奇", "ko": "전설"},
	"league_0": {"tr": "Mahalle Ligi", "en": "Street League", "ru": "Дворовая лига", "uz": "Mahalla ligasi", "zh": "街头联赛", "ko": "동네 리그"},
	"league_1": {"tr": "Amatör Lig", "en": "Amateur League", "ru": "Любительская лига", "uz": "Havaskorlar ligasi", "zh": "业余联赛", "ko": "아마추어 리그"},
	"league_2": {"tr": "Süper Lig", "en": "Super League", "ru": "Суперлига", "uz": "Superliga", "zh": "超级联赛", "ko": "슈퍼 리그"},
	"league_3": {"tr": "Avrupa Kupası", "en": "Euro Cup", "ru": "Еврокубок", "uz": "Yevropa kubogi", "zh": "欧洲杯", "ko": "유럽 컵"},
	"league_4": {"tr": "Dünya Finali", "en": "World Final", "ru": "Финал мира", "uz": "Jahon finali", "zh": "世界决赛", "ko": "월드 파이널"},
	"level_n": {"tr": "Bölüm {v}", "en": "Level {v}", "ru": "Уровень {v}", "uz": "Bosqich {v}", "zh": "第 {v} 关", "ko": "레벨 {v}"},
	"locked": {"tr": "Kilitli", "en": "Locked", "ru": "Закрыто", "uz": "Qulflangan", "zh": "未解锁", "ko": "잠김"},
	"skip_level": {"tr": "Reklam izle, bölümü geç", "en": "Watch an ad to skip", "ru": "Смотреть рекламу и пропустить", "uz": "Reklama koʻrib oʻtkazish", "zh": "看广告跳过本关", "ko": "광고 보고 건너뛰기"},
	"start_match": {"tr": "Maça başla", "en": "Kick off", "ru": "Начать матч", "uz": "Oʻyinni boshlash", "zh": "开始比赛", "ko": "경기 시작"},
	"keeper_style": {"tr": "Rakip: {v}", "en": "Opponent: {v}", "ru": "Соперник: {v}", "uz": "Raqib: {v}", "zh": "对手：{v}", "ko": "상대: {v}"},
	"style_0": {"tr": "Aceleci", "en": "Hasty", "ru": "Торопливый", "uz": "Shoshqaloq", "zh": "急躁型", "ko": "성급한"},
	"style_1": {"tr": "Sabırlı", "en": "Patient", "ru": "Терпеливый", "uz": "Sabrli", "zh": "耐心型", "ko": "인내심 있는"},
	"style_2": {"tr": "Kurnaz", "en": "Cunning", "ru": "Хитрый", "uz": "Ayyor", "zh": "狡猾型", "ko": "교활한"},
	"style_3": {"tr": "Analizci", "en": "Analyst", "ru": "Аналитик", "uz": "Tahlilchi", "zh": "分析型", "ko": "분석가"},
	"you": {"tr": "SEN", "en": "YOU", "ru": "ТЫ", "uz": "SIZ", "zh": "你", "ko": "나"},
	"ai": {"tr": "YAPAY ZEKÂ", "en": "AI", "ru": "ИИ", "uz": "SI", "zh": "AI", "ko": "AI"},
	"your_turn_shoot": {"tr": "Şut sırası sende: kaydır!", "en": "Your shot: swipe!", "ru": "Твой удар: проведи пальцем!", "uz": "Zarba sizda: suring!", "zh": "轮到你射门：滑动！", "ko": "당신의 슛: 스와이프!"},
	"your_turn_keep": {"tr": "Kaleci sensin: dalış yönüne kaydır!", "en": "You're in goal: swipe to dive!", "ru": "Ты на воротах: проведи для прыжка!", "uz": "Darvozadasiz: sakrash uchun suring!", "zh": "你是门将：滑动扑救！", "ko": "골키퍼 차례: 스와이프해서 다이빙!"},
	"reading": {"tr": "Seni okuyor: %{v}", "en": "Reading you: {v}%", "ru": "Читает тебя: {v}%", "uz": "Sizni oʻqiyapti: {v}%", "zh": "读懂你：{v}%", "ko": "당신을 읽는 중: {v}%"},
	"hint_watch": {"tr": "{v} dikkat!", "en": "Watch {v}!", "ru": "Осторожно: {v}!", "uz": "{v} ehtiyot!", "zh": "注意{v}！", "ko": "{v} 조심!"},
	"zone_0": {"tr": "sol üst", "en": "top left", "ru": "левый верх", "uz": "chap yuqori", "zh": "左上", "ko": "왼쪽 위"},
	"zone_1": {"tr": "orta üst", "en": "top centre", "ru": "центр верх", "uz": "oʻrta yuqori", "zh": "正上", "ko": "가운데 위"},
	"zone_2": {"tr": "sağ üst", "en": "top right", "ru": "правый верх", "uz": "oʻng yuqori", "zh": "右上", "ko": "오른쪽 위"},
	"zone_3": {"tr": "sol orta", "en": "middle left", "ru": "левый центр", "uz": "chap oʻrta", "zh": "左中", "ko": "왼쪽 가운데"},
	"zone_4": {"tr": "orta", "en": "centre", "ru": "центр", "uz": "oʻrta", "zh": "正中", "ko": "가운데"},
	"zone_5": {"tr": "sağ orta", "en": "middle right", "ru": "правый центр", "uz": "oʻng oʻrta", "zh": "右中", "ko": "오른쪽 가운데"},
	"zone_6": {"tr": "sol alt", "en": "bottom left", "ru": "левый низ", "uz": "chap past", "zh": "左下", "ko": "왼쪽 아래"},
	"zone_7": {"tr": "orta alt", "en": "bottom centre", "ru": "центр низ", "uz": "oʻrta past", "zh": "正下", "ko": "가운데 아래"},
	"zone_8": {"tr": "sağ alt", "en": "bottom right", "ru": "правый низ", "uz": "oʻng past", "zh": "右下", "ko": "오른쪽 아래"},
	"goal": {"tr": "GOOOOL!", "en": "GOOOAL!", "ru": "ГООООЛ!", "uz": "GOOOL!", "zh": "球进啦！", "ko": "고오오올!"},
	"saved": {"tr": "KURTARDI!", "en": "SAVED!", "ru": "СЕЙВ!", "uz": "QAYTARDI!", "zh": "扑出！", "ko": "선방!"},
	"you_saved": {"tr": "KURTARDIN!", "en": "GREAT SAVE!", "ru": "ОТЛИЧНЫЙ СЕЙВ!", "uz": "AJOYIB QAYTARISH!", "zh": "漂亮扑救！", "ko": "멋진 선방!"},
	"post": {"tr": "DİREK!", "en": "POST!", "ru": "ШТАНГА!", "uz": "USTUN!", "zh": "击中门柱！", "ko": "골대!"},
	"miss": {"tr": "AUT!", "en": "WIDE!", "ru": "МИМО!", "uz": "CHETGA!", "zh": "射偏！", "ko": "빗나감!"},
	"sudden_death": {"tr": "Seri penaltı!", "en": "Sudden death!", "ru": "Серия до первого промаха!", "uz": "Hal qiluvchi zarbalar!", "zh": "突然死亡！", "ko": "서든 데스!"},
	"win": {"tr": "KAZANDIN!", "en": "YOU WIN!", "ru": "ПОБЕДА!", "uz": "GʻALABA!", "zh": "你赢了！", "ko": "승리!"},
	"lose": {"tr": "KAYBETTİN", "en": "YOU LOST", "ru": "ПОРАЖЕНИЕ", "uz": "MAGʻLUBIYAT", "zh": "你输了", "ko": "패배"},
	"analysis": {"tr": "Yapay zekâ analizi", "en": "AI analysis", "ru": "Анализ ИИ", "uz": "SI tahlili", "zh": "AI 分析", "ko": "AI 분석"},
	"read_you": {"tr": "Seni %{v} oranında doğru tahmin ettim.", "en": "I predicted you correctly {v}% of the time.", "ru": "Я угадал твои удары на {v}%.", "uz": "Sizni {v}% toʻgʻri taxmin qildim.", "zh": "我有 {v}% 的次数猜中了你。", "ko": "당신을 {v}% 맞혔어요."},
	"habit": {"tr": "En sevdiğin köşe: {v}", "en": "Your favourite spot: {v}", "ru": "Твой любимый угол: {v}", "uz": "Sevimli burchagingiz: {v}", "zh": "你最爱的位置：{v}", "ko": "가장 좋아하는 코스: {v}"},
	"your_shots": {"tr": "Şut haritan", "en": "Your shot map", "ru": "Карта ударов", "uz": "Zarbalar xaritasi", "zh": "射门分布", "ko": "슛 지도"},
	"next_level": {"tr": "Sonraki bölüm", "en": "Next level", "ru": "Следующий уровень", "uz": "Keyingi bosqich", "zh": "下一关", "ko": "다음 레벨"},
	"retry": {"tr": "Tekrar dene", "en": "Try again", "ru": "Ещё раз", "uz": "Qayta urinish", "zh": "再试一次", "ko": "다시 하기"},
	"main_menu": {"tr": "Ana menü", "en": "Main menu", "ru": "Главное меню", "uz": "Bosh menyu", "zh": "主菜单", "ko": "메인 메뉴"},
	"coins_earned": {"tr": "+{v} jeton", "en": "+{v} coins", "ru": "+{v} монет", "uz": "+{v} tanga", "zh": "+{v} 金币", "ko": "+{v} 코인"},
	"double_coins": {"tr": "Reklam izle: jetonları ikiye katla", "en": "Watch an ad: double coins", "ru": "Реклама: удвоить монеты", "uz": "Reklama: tangalarni ikki baravar", "zh": "看广告：金币翻倍", "ko": "광고 보고 코인 2배"},
	"hint_buy": {"tr": "İpucu: Kalecinin aklını gör", "en": "Hint: see the keeper's guess", "ru": "Подсказка: мысли вратаря", "uz": "Maslahat: darvozabon fikri", "zh": "提示：看门将的预判", "ko": "힌트: 골키퍼의 예측 보기"},
	"hint_shown": {"tr": "Kaleci {v} bekliyor!", "en": "The keeper expects {v}!", "ru": "Вратарь ждёт: {v}!", "uz": "Darvozabon {v} kutyapti!", "zh": "门将预判：{v}！", "ko": "골키퍼는 {v}를 예상!"},
	"paused": {"tr": "Oyun durdu", "en": "Paused", "ru": "Пауза", "uz": "Pauza", "zh": "已暂停", "ko": "일시정지"},
	"resume": {"tr": "Devam et", "en": "Resume", "ru": "Продолжить", "uz": "Davom etish", "zh": "继续", "ko": "계속"},
	"quit_match": {"tr": "Maçtan çık", "en": "Leave match", "ru": "Покинуть матч", "uz": "Oʻyindan chiqish", "zh": "退出比赛", "ko": "경기 나가기"},
	"ad_loading": {"tr": "Reklam yükleniyor…", "en": "Loading ad…", "ru": "Загрузка рекламы…", "uz": "Reklama yuklanmoqda…", "zh": "广告加载中…", "ko": "광고 불러오는 중…"},
	"ad_unavailable": {"tr": "Şu an reklam yok, sonra dene", "en": "No ad available right now", "ru": "Сейчас рекламы нет", "uz": "Hozir reklama yoʻq", "zh": "暂无广告", "ko": "지금은 광고가 없어요"},
	"not_enough_coins": {"tr": "Yeterli jeton yok", "en": "Not enough coins", "ru": "Не хватает монет", "uz": "Tanga yetarli emas", "zh": "金币不足", "ko": "코인이 부족해요"},
	"buy": {"tr": "Al", "en": "Buy", "ru": "Купить", "uz": "Olish", "zh": "购买", "ko": "구매"},
	"equip": {"tr": "Kullan", "en": "Use", "ru": "Использовать", "uz": "Ishlatish", "zh": "使用", "ko": "사용"},
	"equipped": {"tr": "Kullanılıyor", "en": "In use", "ru": "Используется", "uz": "Ishlatilmoqda", "zh": "使用中", "ko": "사용 중"},
	"ball_0": {"tr": "Klasik top", "en": "Classic ball", "ru": "Классический мяч", "uz": "Klassik toʻp", "zh": "经典足球", "ko": "클래식 공"},
	"ball_1": {"tr": "Altın top", "en": "Golden ball", "ru": "Золотой мяч", "uz": "Oltin toʻp", "zh": "金色足球", "ko": "황금 공"},
	"ball_2": {"tr": "Neon top", "en": "Neon ball", "ru": "Неоновый мяч", "uz": "Neon toʻp", "zh": "霓虹足球", "ko": "네온 공"},
	"ball_3": {"tr": "Ateş topu", "en": "Fire ball", "ru": "Огненный мяч", "uz": "Olov toʻp", "zh": "火焰足球", "ko": "불꽃 공"},
	"ball_4": {"tr": "Buz topu", "en": "Ice ball", "ru": "Ледяной мяч", "uz": "Muz toʻp", "zh": "冰霜足球", "ko": "얼음 공"},
	"howto_1": {"tr": "Şut atarken parmağını toptan kaleye doğru kaydır. Kaydırma yönü hedefi, hızı gücü belirler; eğri kaydırırsan top falso alır.", "en": "To shoot, swipe from the ball towards the goal. Direction sets the target, speed sets the power; a curved swipe adds spin.", "ru": "Для удара проведи пальцем от мяча к воротам. Направление — цель, скорость — сила, дуга — подкрутка.", "uz": "Zarba uchun barmogʻingizni toʻpdan darvozaga suring. Yoʻnalish — nishon, tezlik — kuch, egri chiziq — aylanma.", "zh": "射门时从球向球门滑动。方向决定目标，速度决定力量，弧线滑动会产生旋转。", "ko": "슛할 때 공에서 골대 쪽으로 스와이프하세요. 방향은 목표, 속도는 힘, 곡선은 회전을 정해요."},
	"howto_2": {"tr": "Kaleciyken topun gideceği yöne kaydır. Çok erken atlarsan rakip bunu görüp diğer köşeye vurabilir.", "en": "In goal, swipe towards where the ball will go. Dive too early and the shooter may spot it and switch sides.", "ru": "На воротах проведи туда, куда полетит мяч. Прыгнешь рано — соперник ударит в другой угол.", "uz": "Darvozada toʻp boradigan tomonga suring. Erta sakrasangiz, raqib boshqa burchakka uradi.", "zh": "当门将时向球的方向滑动。扑得太早，对手可能改射另一侧。", "ko": "골키퍼일 때 공이 갈 방향으로 스와이프하세요. 너무 일찍 뛰면 상대가 반대로 찰 수 있어요."},
	"howto_3": {"tr": "Yapay zekâ her şutunu hatırlar ve alışkanlıklarını öğrenir. Onu yenmek için tahmin edilemez ol!", "en": "The AI remembers every shot and learns your habits. Be unpredictable to beat it!", "ru": "ИИ запоминает каждый удар и учится твоим привычкам. Будь непредсказуем!", "uz": "SI har bir zarbani eslab, odatlaringizni oʻrganadi. Oldindan bilib boʻlmaydigan boʻling!", "zh": "AI 会记住每一脚射门并学习你的习惯。保持出其不意才能赢！", "ko": "AI는 모든 슛을 기억하고 습관을 배워요. 예측 불가능하게 플레이하세요!"},
	"theme": {"tr": "Görünüm", "en": "Theme", "ru": "Тема", "uz": "Koʻrinish", "zh": "外观", "ko": "테마"},
	"theme_auto": {"tr": "Otomatik", "en": "Auto", "ru": "Авто", "uz": "Avto", "zh": "自动", "ko": "자동"},
	"theme_light": {"tr": "Açık", "en": "Light", "ru": "Светлая", "uz": "Yorugʻ", "zh": "浅色", "ko": "라이트"},
	"theme_dark": {"tr": "Koyu", "en": "Dark", "ru": "Тёмная", "uz": "Qorongʻi", "zh": "深色", "ko": "다크"},
	"language": {"tr": "Dil", "en": "Language", "ru": "Язык", "uz": "Til", "zh": "语言", "ko": "언어"},
	"lang_auto": {"tr": "Telefona göre", "en": "Phone default", "ru": "Как в системе", "uz": "Telefon boʻyicha", "zh": "跟随系统", "ko": "기기 설정"},
	"sound": {"tr": "Ses efektleri", "en": "Sound effects", "ru": "Звуки", "uz": "Ovoz effektlari", "zh": "音效", "ko": "효과음"},
	"music": {"tr": "Stadyum sesi", "en": "Stadium ambience", "ru": "Шум стадиона", "uz": "Stadion ovozi", "zh": "球场氛围", "ko": "경기장 소리"},
	"vibration": {"tr": "Titreşim", "en": "Vibration", "ru": "Вибрация", "uz": "Tebranish", "zh": "振动", "ko": "진동"},
	"reset_ai": {"tr": "Yapay zekânın hafızasını sil", "en": "Reset AI memory", "ru": "Сбросить память ИИ", "uz": "SI xotirasini tozalash", "zh": "清除 AI 记忆", "ko": "AI 기억 초기화"},
	"reset_ai_q": {"tr": "Yapay zekâ seni tanımayı unutsun mu?", "en": "Make the AI forget everything it learned about you?", "ru": "ИИ забудет всё, что узнал о тебе?", "uz": "SI siz haqingizda oʻrgangan hamma narsani unutsinmi?", "zh": "让 AI 忘记关于你的一切？", "ko": "AI가 당신에 대해 배운 것을 잊게 할까요?"},
	"reset_progress": {"tr": "İlerlemeyi sıfırla", "en": "Reset progress", "ru": "Сбросить прогресс", "uz": "Jarayonni tiklash", "zh": "重置进度", "ko": "진행 초기화"},
	"reset_q": {"tr": "Tüm ilerleme silinsin mi?", "en": "Delete all progress?", "ru": "Удалить весь прогресс?", "uz": "Barcha jarayon oʻchirilsinmi?", "zh": "删除全部进度？", "ko": "모든 진행을 삭제할까요?"},
	"done": {"tr": "Tamamlandı", "en": "Done", "ru": "Готово", "uz": "Tayyor", "zh": "完成", "ko": "완료"},
	"privacy": {"tr": "Gizlilik politikası", "en": "Privacy policy", "ru": "Политика конфиденциальности", "uz": "Maxfiylik siyosati", "zh": "隐私政策", "ko": "개인정보 처리방침"},
	"about_body": {"tr": "Penaltı Ustası, cihazında çalışan bir yapay zekâya karşı oynanan penaltı oyunudur. Takım adları ve armaları kullanılmaz; formalar yalnızca renklerden oluşur.", "en": "Penalty Master is a penalty game against an AI that runs on your device. No real team names or crests are used; kits are colours only.", "ru": "«Мастер пенальти» — игра против ИИ, работающего на твоём устройстве. Реальные названия и эмблемы клубов не используются.", "uz": "Penalti ustasi — qurilmangizda ishlaydigan SIga qarshi penalti oʻyini. Haqiqiy klub nomlari va gerblari ishlatilmaydi.", "zh": "点球大师是一款与设备内 AI 对战的点球游戏。不使用真实球队名称或队徽，球衣仅为颜色。", "ko": "페널티 마스터는 기기에서 작동하는 AI와 겨루는 페널티 게임이에요. 실제 팀 이름이나 엠블럼은 사용하지 않아요."},
	"about_data": {"tr": "İnternet gerekmez. Yapay zekânın öğrendikleri yalnızca bu cihazda saklanır.", "en": "No internet needed. What the AI learns stays on this device.", "ru": "Интернет не нужен. Всё, что узнаёт ИИ, хранится только на устройстве.", "uz": "Internet kerak emas. SI oʻrgangan narsalar faqat shu qurilmada saqlanadi.", "zh": "无需联网。AI 学到的内容只保存在本设备上。", "ko": "인터넷이 필요 없어요. AI가 배운 내용은 이 기기에만 저장돼요."},
	"developer": {"tr": "Geliştirici: matali", "en": "Developer: matali", "ru": "Разработчик: matali", "uz": "Ishlab chiquvchi: matali", "zh": "开发者：matali", "ko": "개발자: matali"},
	"version": {"tr": "Sürüm {v}", "en": "Version {v}", "ru": "Версия {v}", "uz": "Versiya {v}", "zh": "版本 {v}", "ko": "버전 {v}"},
	"stars_total": {"tr": "{v} yıldız", "en": "{v} stars", "ru": "{v} звёзд", "uz": "{v} yulduz", "zh": "{v} 颗星", "ko": "별 {v}개"},
	"round": {"tr": "Penaltı {v}", "en": "Penalty {v}", "ru": "Пенальти {v}", "uz": "Penalti {v}", "zh": "第 {v} 轮", "ko": "페널티 {v}"},
	"ai_guess": {"tr": "Yapay zekâ tahmini: %{p} {z}", "en": "AI prediction: {p}% {z}", "ru": "Прогноз ИИ: {p}% {z}", "uz": "SI taxmini: {p}% {z}", "zh": "AI 预测：{p}% {z}", "ko": "AI 예측: {p}% {z}"},
	"ai_analyzing": {"tr": "Yapay zekâ veri topluyor… Seni analiz ediyor", "en": "AI is collecting data… analysing you", "ru": "ИИ собирает данные… анализирует тебя", "uz": "SI maʼlumot yigʻmoqda… sizni tahlil qilmoqda", "zh": "AI 正在收集数据……分析你", "ko": "AI가 데이터를 수집 중… 당신을 분석 중"},
}

func _ready() -> void:
	apply_setting("auto")


func detect_system_language() -> String:
	var l: String = OS.get_locale_language().to_lower()
	if l in LANGS:
		return l
	return "en"


func apply_setting(setting: String) -> void:
	var new_lang: String = detect_system_language() if setting == "auto" or not (setting in LANGS) else setting
	if new_lang != lang:
		lang = new_lang
		TranslationServer.set_locale(lang)
		language_changed.emit()


func t(key: String, args: Dictionary = {}) -> String:
	var text: String = key
	if S.has(key):
		var entry: Dictionary = S[key]
		if entry.has(lang):
			text = entry[lang]
		elif entry.has("en"):
			text = entry["en"]
	for k in args.keys():
		text = text.replace("{" + str(k) + "}", str(args[k]))
	return text


func missing_report() -> Array[String]:
	## Test için: eksik çeviri anahtarlarını listeler.
	var out: Array[String] = []
	for key in S.keys():
		var entry: Dictionary = S[key]
		for l in LANGS:
			if not entry.has(l) or str(entry[l]).strip_edges() == "":
				out.append("%s/%s" % [key, l])
	return out
