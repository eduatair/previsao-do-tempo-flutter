import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const PrevisaoApp());
}

class PrevisaoApp extends StatelessWidget {
  const PrevisaoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Previsão do Tempo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF176B87),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF2F7FA),
      ),
      home: const PrevisaoScreen(),
    );
  }
}

// ========================= MODEL =========================

class Cidade {
  final String nome;
  final String pais;
  final String? estado;
  final double latitude;
  final double longitude;

  const Cidade({
    required this.nome,
    required this.pais,
    this.estado,
    required this.latitude,
    required this.longitude,
  });

  factory Cidade.fromJson(Map<String, dynamic> json) {
    return Cidade(
      nome: json['name'] as String? ?? 'Cidade',
      pais: json['country'] as String? ?? '',
      estado: json['admin1'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  String get identificacao {
    final partes = <String>[nome];
    if (estado != null && estado!.isNotEmpty) partes.add(estado!);
    if (pais.isNotEmpty) partes.add(pais);
    return partes.join(' - ');
  }
}

class Previsao {
  final double temperatura;
  final int umidade;
  final double precipitacao;
  final double chuva;
  final double vento;
  final List<dynamic> horarios;
  final List<dynamic> temperaturasHora;
  final List<dynamic> probabilidadesChuva;
  final List<dynamic> dias;
  final List<dynamic> maximas;
  final List<dynamic> minimas;
  final List<dynamic> precipitacaoDiaria;
  final List<dynamic> probabilidadeDiaria;

  const Previsao({
    required this.temperatura,
    required this.umidade,
    required this.precipitacao,
    required this.chuva,
    required this.vento,
    required this.horarios,
    required this.temperaturasHora,
    required this.probabilidadesChuva,
    required this.dias,
    required this.maximas,
    required this.minimas,
    required this.precipitacaoDiaria,
    required this.probabilidadeDiaria,
  });

  factory Previsao.fromJson(Map<String, dynamic> json) {
    final atual = json['current'] as Map<String, dynamic>;
    final horario = json['hourly'] as Map<String, dynamic>;
    final diario = json['daily'] as Map<String, dynamic>;

    return Previsao(
      temperatura: (atual['temperature_2m'] as num).toDouble(),
      umidade: (atual['relative_humidity_2m'] as num).toInt(),
      precipitacao: (atual['precipitation'] as num).toDouble(),
      chuva: (atual['rain'] as num).toDouble(),
      vento: (atual['wind_speed_10m'] as num).toDouble(),
      horarios: horario['time'] as List<dynamic>,
      temperaturasHora: horario['temperature_2m'] as List<dynamic>,
      probabilidadesChuva:
          horario['precipitation_probability'] as List<dynamic>,
      dias: diario['time'] as List<dynamic>,
      maximas: diario['temperature_2m_max'] as List<dynamic>,
      minimas: diario['temperature_2m_min'] as List<dynamic>,
      precipitacaoDiaria: diario['precipitation_sum'] as List<dynamic>,
      probabilidadeDiaria:
          diario['precipitation_probability_max'] as List<dynamic>,
    );
  }
}

// ========================= SERVICE =========================

class ClimaService {
  static Future<List<Cidade>> buscarCidades(String nome) async {
    final uri = Uri.https(
      'geocoding-api.open-meteo.com',
      '/v1/search',
      {
        'name': nome,
        'count': '10',
        'language': 'pt',
        'format': 'json',
      },
    );

    final resposta = await http
        .get(uri)
        .timeout(const Duration(seconds: 15));

    if (resposta.statusCode != 200) {
      throw Exception('Não foi possível pesquisar a cidade.');
    }

    final json = jsonDecode(utf8.decode(resposta.bodyBytes))
        as Map<String, dynamic>;
    final resultados = json['results'] as List<dynamic>? ?? [];

    return resultados
        .map((item) => Cidade.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<Previsao> buscarPrevisao(Cidade cidade) async {
    final uri = Uri.https(
      'api.open-meteo.com',
      '/v1/forecast',
      {
        'latitude': cidade.latitude.toString(),
        'longitude': cidade.longitude.toString(),
        'current':
            'temperature_2m,relative_humidity_2m,precipitation,rain,wind_speed_10m',
        'hourly':
            'temperature_2m,precipitation_probability,precipitation,rain',
        'daily':
            'temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max',
        'timezone': 'America/Sao_Paulo',
      },
    );

    final resposta = await http
        .get(uri)
        .timeout(const Duration(seconds: 15));

    if (resposta.statusCode != 200) {
      throw Exception('Não foi possível carregar a previsão do tempo.');
    }

    final json = jsonDecode(utf8.decode(resposta.bodyBytes))
        as Map<String, dynamic>;
    return Previsao.fromJson(json);
  }
}

// ========================= SCREEN =========================

class PrevisaoScreen extends StatefulWidget {
  const PrevisaoScreen({super.key});

  @override
  State<PrevisaoScreen> createState() => _PrevisaoScreenState();
}

class _PrevisaoScreenState extends State<PrevisaoScreen> {
  final TextEditingController _cidadeController =
      TextEditingController(text: 'São Sebastião do Paraíso');

  bool _buscandoCidades = false;
  bool _buscandoPrevisao = false;
  String? _erro;
  List<Cidade> _cidadesEncontradas = [];
  Cidade? _cidadeSelecionada;
  Previsao? _previsao;

  @override
  void dispose() {
    _cidadeController.dispose();
    super.dispose();
  }

  Future<void> _pesquisarCidade() async {
    final nome = _cidadeController.text.trim();

    if (nome.isEmpty) {
      setState(() => _erro = 'Digite o nome de uma cidade.');
      return;
    }

    setState(() {
      _buscandoCidades = true;
      _erro = null;
      _cidadesEncontradas = [];
      _cidadeSelecionada = null;
      _previsao = null;
    });

    try {
      final cidades = await ClimaService.buscarCidades(nome);
      if (!mounted) return;

      setState(() {
        _cidadesEncontradas = cidades;
        _buscandoCidades = false;
        if (cidades.isEmpty) {
          _erro = 'Nenhuma cidade encontrada. Verifique o nome e tente novamente.';
        }
      });

      // Quando só existe um resultado, a previsão é carregada automaticamente.
      if (cidades.length == 1) {
        await _selecionarCidade(cidades.first);
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _buscandoCidades = false;
        _erro = 'A pesquisa demorou demais. Verifique sua conexão.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _buscandoCidades = false;
        _erro = 'Erro ao pesquisar cidade. Tente novamente.';
      });
    }
  }

  Future<void> _selecionarCidade(Cidade cidade) async {
    setState(() {
      _cidadeSelecionada = cidade;
      _buscandoPrevisao = true;
      _erro = null;
      _previsao = null;
    });

    try {
      final resultado = await ClimaService.buscarPrevisao(cidade);
      if (!mounted) return;
      setState(() {
        _previsao = resultado;
        _buscandoPrevisao = false;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _buscandoPrevisao = false;
        _erro = 'A consulta da previsão demorou demais. Tente novamente.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _buscandoPrevisao = false;
        _erro = 'Não foi possível carregar a previsão desta cidade.';
      });
    }
  }

  String _formatarDia(dynamic valor) {
    final data = DateTime.tryParse(valor.toString());
    if (data == null) return valor.toString();
    const dias = [
      'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'
    ];
    return '${dias[data.weekday - 1]}, ${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}';
  }

  String _formatarHora(dynamic valor) {
    final texto = valor.toString();
    if (texto.length >= 16) return texto.substring(11, 16);
    return texto;
  }

  @override
  Widget build(BuildContext context) {
    final previsao = _previsao;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Previsão do Tempo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF176B87),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _campoPesquisa(),
            const SizedBox(height: 16),

            if (_buscandoCidades || _buscandoPrevisao)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Consultando informações...'),
                    ],
                  ),
                ),
              ),

            if (_erro != null) _mensagemErro(_erro!),

            if (_cidadesEncontradas.length > 1 &&
                _cidadeSelecionada == null &&
                !_buscandoCidades) ...[
              const Text(
                'Selecione a cidade:',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._cidadesEncontradas.map(
                (cidade) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(cidade.nome),
                    subtitle: Text(
                      [
                        if (cidade.estado != null) cidade.estado!,
                        cidade.pais,
                      ].join(' - '),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _selecionarCidade(cidade),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (previsao != null && _cidadeSelecionada != null) ...[
              _cartaoAtual(previsao, _cidadeSelecionada!),
              const SizedBox(height: 20),
              const Text(
                'Próximas horas',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _previsaoPorHora(previsao),
              const SizedBox(height: 20),
              const Text(
                'Previsão dos próximos dias',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _previsaoDiaria(previsao),
            ],

            if (previsao == null &&
                !_buscandoCidades &&
                !_buscandoPrevisao &&
                _erro == null &&
                _cidadesEncontradas.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 35),
                child: Column(
                  children: [
                    Icon(Icons.cloud_outlined, size: 76, color: Colors.blueGrey),
                    SizedBox(height: 12),
                    Text(
                      'Pesquise uma cidade para consultar o clima.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.blueGrey),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _campoPesquisa() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Encontre uma cidade',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _cidadeController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _pesquisarCidade(),
              decoration: InputDecoration(
                hintText: 'Ex.: São Sebastião do Paraíso',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_buscandoCidades || _buscandoPrevisao)
                    ? null
                    : _pesquisarCidade,
                icon: const Icon(Icons.cloud),
                label: const Text('Buscar previsão'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mensagemErro(String mensagem) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(child: Text(mensagem)),
            IconButton(
              tooltip: 'Tentar novamente',
              onPressed: _pesquisarCidade,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartaoAtual(Previsao p, Cidade cidade) {
    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF176B87), Color(0xFF64CCC5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Clima agora',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 5),
            Text(
              cidade.identificacao,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.wb_sunny, color: Colors.white, size: 58),
                const SizedBox(width: 14),
                Text(
                  '${p.temperatura.toStringAsFixed(1)}°C',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white54, height: 28),
            Wrap(
              spacing: 18,
              runSpacing: 14,
              children: [
                _indicador(Icons.water_drop, 'Umidade', '${p.umidade}%'),
                _indicador(Icons.grain, 'Precipitação',
                    '${p.precipitacao.toStringAsFixed(1)} mm'),
                _indicador(Icons.umbrella, 'Chuva',
                    '${p.chuva.toStringAsFixed(1)} mm'),
                _indicador(Icons.air, 'Vento',
                    '${p.vento.toStringAsFixed(1)} km/h'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _indicador(IconData icone, String titulo, String valor) {
    return SizedBox(
      width: 135,
      child: Row(
        children: [
          Icon(icone, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text(
                  valor,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _previsaoPorHora(Previsao p) {
    final agora = DateTime.now();
    int inicio = 0;

    for (int i = 0; i < p.horarios.length; i++) {
      final data = DateTime.tryParse(p.horarios[i].toString());
      if (data != null && !data.isBefore(agora)) {
        inicio = i;
        break;
      }
    }

    final fim = (inicio + 12 < p.horarios.length)
        ? inicio + 12
        : p.horarios.length;

    return SizedBox(
      height: 145,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: fim - inicio,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final i = inicio + index;
          final temperatura = (p.temperaturasHora[i] as num).toDouble();
          final chance = (p.probabilidadesChuva[i] as num).toInt();

          return Container(
            width: 92,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text(_formatarHora(p.horarios[i])),
                const Icon(Icons.cloud_outlined,
                    color: Color(0xFF176B87), size: 27),
                Text('${temperatura.toStringAsFixed(0)}°C',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.water_drop, size: 13, color: Colors.blue),
                    Text('$chance%', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _previsaoDiaria(Previsao p) {
    return Card(
      child: Column(
        children: List.generate(p.dias.length, (i) {
          final maxima = (p.maximas[i] as num).toDouble();
          final minima = (p.minimas[i] as num).toDouble();
          final chuva = (p.precipitacaoDiaria[i] as num).toDouble();
          final chance = (p.probabilidadeDiaria[i] as num).toInt();

          return Column(
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_today,
                    color: Color(0xFF176B87)),
                title: Text(_formatarDia(p.dias[i])),
                subtitle: Text(
                  'Chuva: ${chuva.toStringAsFixed(1)} mm • Probabilidade: $chance%',
                ),
                trailing: Text(
                  '${maxima.toStringAsFixed(0)}° / ${minima.toStringAsFixed(0)}°',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (i != p.dias.length - 1) const Divider(height: 1),
            ],
          );
        }),
      ),
    );
  }
}
