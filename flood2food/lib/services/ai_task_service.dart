import 'dart:math';
import '../models/sensor_data.dart';
import '../models/daily_task.dart';

class AiTaskService {
  static final _random = Random();

  static List<DailyTask> generateDailyTasks(SensorData data) {
    final tasks = <DailyTask>[];
    
    tasks.addAll(_npkBasedTasks(data));
    tasks.addAll(_humidityBasedTasks(data));
    tasks.addAll(_phBasedTasks(data));
    tasks.addAll(_ecBasedTasks(data));
    tasks.add(_generalMaintenanceTask());
    
    tasks.shuffle();
    return tasks.take(5).toList();
  }

  static String _randId(String prefix) => '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1000)}';

  static List<DailyTask> _npkBasedTasks(SensorData data) {
    final tasks = <DailyTask>[];
    
    // NITROGEN (N)
    if (data.nitrogen < 15) {
      final templates = [
        DailyTask(
          id: _randId('n_low'),
          title: 'Aplikasi Urea Cepat Larut',
          description: 'Kadar N sangat kritis (${data.nitrogen.toStringAsFixed(1)} mg/kg). Taburkan 50 gram Urea per meter persegi, lalu siram agar cepat terserap akar.',
          category: TaskCategory.fertilizing,
          difficulty: TaskDifficulty.medium,
          xpReward: 35,
          pointReward: 15,
          aiReason: 'Nitrogen (${data.nitrogen.toStringAsFixed(1)} mg/kg) di bawah standar 20 mg/kg. Tanaman padi berisiko kerdil kuning.',
        ),
        DailyTask(
          id: _randId('n_low'),
          title: 'Pemupukan Kompos Organik',
          description: 'Nitrogen tanah kurang. Tebarkan 1 kg pupuk kandang ayam atau kompos daun matang secara merata di area perakaran.',
          category: TaskCategory.fertilizing,
          difficulty: TaskDifficulty.hard,
          xpReward: 45,
          pointReward: 20,
          aiReason: 'Pupuk organik melepaskan nitrogen perlahan. N saat ini ${data.nitrogen.toStringAsFixed(1)} mg/kg, butuh suplemen jangka panjang.',
        ),
        DailyTask(
          id: _randId('n_low'),
          title: 'Semprot Pupuk Daun Nitrogen',
          description: 'Larutkan 10 ml pupuk daun tinggi N (seperti Gandapan) ke dalam 1 liter air, semprot merata pada daun di pagi hari.',
          category: TaskCategory.fertilizing,
          difficulty: TaskDifficulty.medium,
          xpReward: 30,
          pointReward: 15,
          aiReason: 'Penyerapan via stomata sangat efektif saat akar kesulitan menyerap N yang hanya ${data.nitrogen.toStringAsFixed(1)} mg/kg.',
        ),
      ];
      tasks.add(templates[_random.nextInt(templates.length)]);
    } else if (data.nitrogen > 80) {
      tasks.add(
        DailyTask(
          id: _randId('n_high'),
          title: 'Bilas Tanah (Flushing N)',
          description: 'Nitrogen berlebih (${data.nitrogen.toStringAsFixed(1)} mg/kg). Siram genangan air hingga melimpah selama 15 menit agar sisa urea tercuci dari lahan.',
          category: TaskCategory.watering,
          difficulty: TaskDifficulty.hard,
          xpReward: 40,
          pointReward: 20,
          aiReason: 'Kadar N > 80 mg/kg memicu padi rebah dan rentan hama wereng. Harus segera dicuci.',
        )
      );
    }

    // FOSFOR (P)
    if (data.phosphorus < 10) {
      final templates = [
        DailyTask(
          id: _randId('p_low'),
          title: 'Injeksi Pupuk SP-36',
          description: 'Fosfor sangat rendah (${data.phosphorus.toStringAsFixed(1)} mg/kg). Benamkan 75 gram pupuk SP-36 di kedalaman 5 cm dekat perakaran.',
          category: TaskCategory.fertilizing,
          difficulty: TaskDifficulty.medium,
          xpReward: 35,
          pointReward: 15,
          aiReason: 'Fosfor mutlak diperlukan untuk anakan padi. Level ${data.phosphorus.toStringAsFixed(1)} mg/kg menghambat pertumbuhan akar.',
        ),
        DailyTask(
          id: _randId('p_low'),
          title: 'Tabur Tepung Tulang',
          description: 'Tebarkan 100 gram tepung tulang (bone meal) organik merata di area tanam sebagai asupan Fosfor lambat.',
          category: TaskCategory.fertilizing,
          difficulty: TaskDifficulty.easy,
          xpReward: 25,
          pointReward: 10,
          aiReason: 'Tepung tulang kaya P alami untuk pemulihan tanah jangka panjang. P saat ini: ${data.phosphorus.toStringAsFixed(1)} mg/kg.',
        ),
      ];
      tasks.add(templates[_random.nextInt(templates.length)]);
    }

    // KALIUM (K)
    if (data.kalium < 15) {
      final templates = [
        DailyTask(
          id: _randId('k_low'),
          title: 'Taburkan Pupuk KCL',
          description: 'Kadar Kalium drop (${data.kalium.toStringAsFixed(1)} mg/kg). Aplikasikan 50 gram KCL secara melingkar sejauh 10 cm dari pangkal batang.',
          category: TaskCategory.fertilizing,
          difficulty: TaskDifficulty.medium,
          xpReward: 30,
          pointReward: 15,
          aiReason: 'Kekurangan K (${data.kalium.toStringAsFixed(1)} mg/kg) membuat batang loyo dan mudah terserang penyakit bulai.',
        ),
        DailyTask(
          id: _randId('k_low'),
          title: 'Sebar Abu Bakaran Kayu',
          description: 'Gunakan abu sisa pembakaran kayu/sekam sebanyak 200 gram per meter persegi. Ini sumber Kalium organik gratis.',
          category: TaskCategory.fertilizing,
          difficulty: TaskDifficulty.easy,
          xpReward: 20,
          pointReward: 10,
          aiReason: 'Abu kayu menaikkan kalium sekaligus menetralisir asam. Kadar K saat ini ${data.kalium.toStringAsFixed(1)} mg/kg.',
        ),
      ];
      tasks.add(templates[_random.nextInt(templates.length)]);
    }
    
    return tasks;
  }

  static List<DailyTask> _humidityBasedTasks(SensorData data) {
    final tasks = <DailyTask>[];
    if (data.humidity < 35) {
      final templates = [
        DailyTask(
          id: _randId('hum_low'),
          title: 'Banjiri Petak Sawah',
          description: 'Kelembaban tanah ${data.humidity.toStringAsFixed(1)}%. Alirkan air irigasi hingga air menggenang setinggi 3-5 cm dari permukaan tanah.',
          category: TaskCategory.watering,
          difficulty: TaskDifficulty.hard,
          xpReward: 40,
          pointReward: 20,
          aiReason: 'Padi butuh air menggenang. Kelembaban ${data.humidity.toStringAsFixed(1)}% menandakan retak rambut tanah mulai muncul.',
        ),
        DailyTask(
          id: _randId('hum_low'),
          title: 'Penyiraman Intensif',
          description: 'Siram tanah secara merata menggunakan pompa sedot sebanyak 50 liter per petak ukuran 5x5 meter.',
          category: TaskCategory.watering,
          difficulty: TaskDifficulty.medium,
          xpReward: 30,
          pointReward: 15,
          aiReason: 'Menjaga lengas tanah di atas 50% krusial untuk mencegah daun menggulung akibat stres air.',
        ),
      ];
      tasks.add(templates[_random.nextInt(templates.length)]);
    } else if (data.humidity > 85) {
      tasks.add(
        DailyTask(
          id: _randId('hum_high'),
          title: 'Kuras Genangan Air (Macak-macak)',
          description: 'Kelembaban ${data.humidity.toStringAsFixed(1)}%. Buka saluran pembuangan dan biarkan sisa air surut hingga kondisi macak-macak (lumpur basah tanpa genangan).',
          category: TaskCategory.watering,
          difficulty: TaskDifficulty.medium,
          xpReward: 35,
          pointReward: 18,
          aiReason: 'Genangan berlebih memicu akar membusuk dan menghalangi oksigen masuk ke dalam pori-pori tanah.',
        )
      );
    } else {
      tasks.add(
        DailyTask(
          id: _randId('hum_ok'),
          title: 'Pertahankan Level Air',
          description: 'Kelembaban optimal (${data.humidity.toStringAsFixed(1)}%). Pastikan tidak ada kebocoran di pematang sawah agar air tetap stabil.',
          category: TaskCategory.watering,
          difficulty: TaskDifficulty.easy,
          xpReward: 15,
          pointReward: 8,
          aiReason: 'Kelembaban sawah terjaga di kondisi prima.',
        )
      );
    }
    return tasks;
  }

  static List<DailyTask> _phBasedTasks(SensorData data) {
    final tasks = <DailyTask>[];
    if (data.ph < 5.0) {
      final templates = [
        DailyTask(
          id: _randId('ph_low'),
          title: 'Tebarkan Kapur Dolomit',
          description: 'Kondisi tanah sangat masam (pH ${data.ph.toStringAsFixed(1)}). Taburkan 150 gram kapur Dolomit per meter persegi pada tanah basah.',
          category: TaskCategory.pHAdjustment,
          difficulty: TaskDifficulty.hard,
          xpReward: 45,
          pointReward: 25,
          aiReason: 'pH ${data.ph.toStringAsFixed(1)} membuat racun Aluminium & Besi aktif. Dolomit butuh 1 minggu untuk menetralisirnya.',
        ),
        DailyTask(
          id: _randId('ph_low'),
          title: 'Bilas Asam Permukaan',
          description: 'Buka pintu irigasi lebar-lebar. Alirkan air bersih masuk-keluar lahan selama 1 jam untuk mencuci senyawa asam pascabanjir.',
          category: TaskCategory.pHAdjustment,
          difficulty: TaskDifficulty.medium,
          xpReward: 35,
          pointReward: 18,
          aiReason: 'Sistem flushing adalah cara paling cepat membuang tumpukan asam sulfida akibat perendaman lahan banjir.',
        ),
      ];
      tasks.add(templates[_random.nextInt(templates.length)]);
    } else if (data.ph > 8.0) {
      tasks.add(
        DailyTask(
          id: _randId('ph_high'),
          title: 'Aplikasi Sulfur / Belerang',
          description: 'pH basa ekstrim (${data.ph.toStringAsFixed(1)}). Campurkan 50 gram belerang bubuk ke dalam tanah dan siram hingga larut.',
          category: TaskCategory.pHAdjustment,
          difficulty: TaskDifficulty.hard,
          xpReward: 50,
          pointReward: 30,
          aiReason: 'pH basa (>8.0) mengikat fosfor dan seng sehingga tanaman padi menjadi pucat dan kerdil.',
        )
      );
    }
    return tasks;
  }

  static List<DailyTask> _ecBasedTasks(SensorData data) {
    final tasks = <DailyTask>[];
    if (data.ec > 2.5) {
      tasks.add(
        DailyTask(
          id: _randId('ec_high'),
          title: 'Flushing Garam (Leaching)',
          description: 'EC tanah tinggi (${data.ec.toStringAsFixed(2)} mS/cm). Lakukan pembilasan menggunakan 100 liter air per petak. Pastikan air mengalir keluar lahan.',
          category: TaskCategory.soilCheck,
          difficulty: TaskDifficulty.hard,
          xpReward: 40,
          pointReward: 20,
          aiReason: 'Nilai EC tinggi menandakan penumpukan sisa pupuk kimia beracun. Harus dicuci agar akar bisa bernapas.',
        )
      );
    } else if (data.ec < 0.3) {
      final templates = [
        DailyTask(
          id: _randId('ec_low'),
          title: 'Injeksi Nutrisi Lengkap (POC)',
          description: 'EC sangat rendah (${data.ec.toStringAsFixed(2)} mS/cm) artinya tanah "kosong". Kocor 250ml Pupuk Organik Cair (POC) pada area akar terpusat.',
          category: TaskCategory.fertilizing,
          difficulty: TaskDifficulty.medium,
          xpReward: 35,
          pointReward: 15,
          aiReason: 'Pupuk cair akan menaikkan ion terlarut (EC) secara instan, menyembuhkan tanah yang hampa nutrisi pascabanjir.',
        ),
        DailyTask(
          id: _randId('ec_low'),
          title: 'Tabur Kompos Beragam',
          description: 'Tambahkan 2 kg kompos campuran (kotoran sapi + dedaunan) untuk memulihkan mikroba dan mineral tanah yang hilang.',
          category: TaskCategory.fertilizing,
          difficulty: TaskDifficulty.medium,
          xpReward: 30,
          pointReward: 15,
          aiReason: 'Daya hantar listrik (EC) ${data.ec.toStringAsFixed(2)} mS/cm menunjukkan tanah kehilangan banyak mineral terlarut.',
        ),
      ];
      tasks.add(templates[_random.nextInt(templates.length)]);
    }
    return tasks;
  }

  static DailyTask _generalMaintenanceTask() {
    final templates = [
      DailyTask(
        id: _randId('gen_weed'),
        title: 'Cabut Gulma Sekitar Sensor',
        description: 'Ada risiko akar gulma menutupi probe sensor. Cabut rumput liar di radius 50 cm dari tiang sensor.',
        category: TaskCategory.general,
        difficulty: TaskDifficulty.easy,
        xpReward: 15,
        pointReward: 8,
        aiReason: 'Akar gulma dapat mengacaukan pembacaan NPK dan menyedot air tanah secara agresif.',
      ),
      DailyTask(
        id: _randId('gen_inspect'),
        title: 'Inspeksi Telur Keong Mas',
        description: 'Kelilingi petakan dan hancurkan jika menemukan kelompok telur keong mas (berwarna pink cerah) di batang padi.',
        category: TaskCategory.general,
        difficulty: TaskDifficulty.medium,
        xpReward: 25,
        pointReward: 12,
        aiReason: 'Pasca genangan banjir, keong mas sering bertelur. Menghancurkan 1 rumpun telur mencegah ledakan 500 keong muda.',
      ),
      DailyTask(
        id: _randId('gen_probe'),
        title: 'Bersihkan Probe Sensor RS485',
        description: 'Angkat tiang sensor. Lap besi probe 7-pin menggunakan kain lembab bersih. Jangan gunakan amplas!',
        category: TaskCategory.general,
        difficulty: TaskDifficulty.medium,
        xpReward: 30,
        pointReward: 15,
        aiReason: 'Lumpur kental sisa banjir sering mengering dan mengerak di elektroda, menurunkan akurasi pembacaan EC.',
      ),
      DailyTask(
        id: _randId('gen_drain'),
        title: 'Cek Saluran Drainase',
        description: 'Telusuri parit/saluran pembuangan air. Singkirkan batang kayu atau lumpur yang menghambat arus air keluar.',
        category: TaskCategory.general,
        difficulty: TaskDifficulty.easy,
        xpReward: 20,
        pointReward: 10,
        aiReason: 'Memastikan aliran lancar krusial saat hujan mendadak turun agar sawah tidak terendam banjir ulang.',
      ),
      DailyTask(
        id: _randId('gen_sun'),
        title: 'Cek Paparan Sinar Matahari',
        description: 'Pastikan tidak ada pelepah daun pohon besar atau jaring burung yang menutupi tanaman padi dari matahari langsung.',
        category: TaskCategory.general,
        difficulty: TaskDifficulty.easy,
        xpReward: 15,
        pointReward: 8,
        aiReason: 'Sinar matahari penuh sangat dibutuhkan untuk memaksimalkan fotosintesis dan pemulihan pascabanjir.',
      ),
    ];
    return templates[_random.nextInt(templates.length)];
  }
}
