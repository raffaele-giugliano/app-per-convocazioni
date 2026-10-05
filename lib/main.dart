import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

const String urlTabellaPartite =
    'https://docs.google.com/spreadsheets/d/e/2PACX-1vTA-oDFCDZIShzqfWXWlxsl1UZjQnlJrR3nmg6c82n9jBFKv5VHb3_RDLUQCAxQpZpJZDki4vVGPdbq/pub?gid=0&single=true&output=csv';
const String urlTabellaGiocatori =
    'https://docs.google.com/spreadsheets/d/e/2PACX-1vTA-oDFCDZIShzqfWXWlxsl1UZjQnlJrR3nmg6c82n9jBFKv5VHb3_RDLUQCAxQpZpJZDki4vVGPdbq/pub?gid=1093465003&single=true&output=csv';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestione Partite',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const PaginaPartite(),
    );
  }
}

// Model per la partita
class Partita {
  final DateTime data;
  final String dataStringa;
  final String squadraOspitante;
  final String squadraOspite;
  final String indirizzo;
  final String oraRitrovo;

  Partita({
    required this.data,
    required this.dataStringa,
    required this.squadraOspitante,
    required this.squadraOspite,
    required this.indirizzo,
    required this.oraRitrovo,
  });
}

// Model per il giocatore
class Giocatore {
  final String cognome;
  final String nome;
  bool convocato;

  Giocatore({
    required this.cognome,
    required this.nome,
    this.convocato = true,
  });
}

// Helper per dividere la riga CSV gestendo eventuali virgolette
List<String> parseCsvLine(String line) {
  List<String> result = [];
  StringBuffer current = StringBuffer();
  bool inQuotes = false;

  for (int i = 0; i < line.length; i++) {
    String char = line[i];
    if (char == '"') {
      inQuotes = !inQuotes;
    } else if (char == ',' && !inQuotes) {
      result.add(current.toString().trim());
      current.clear();
    } else {
      current.write(char);
    }
  }
  result.add(current.toString().trim());
  return result;
}

// --- PAGINA 1: Partite da giocare ---
class PaginaPartite extends StatefulWidget {
  const PaginaPartite({super.key});

  @override
  State<PaginaPartite> createState() => _PaginaPartiteState();
}

class _PaginaPartiteState extends State<PaginaPartite> {
  List<Partita> partite = [];
  Partita? partitaSelezionata;
  bool caricamento = true;
  int indiceProssimaPartita = -1;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    caricaPartite();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> caricaPartite() async {
    try {
      final response = await http.get(Uri.parse(urlTabellaPartite));
      if (response.statusCode == 200) {
        List<String> lines = response.body.split(RegExp(r'\r?\n'));
        List<Partita> tempPartite = [];
        DateTime oggi = DateTime.now();
        DateTime soloOggi = DateTime(oggi.year, oggi.month, oggi.day);

        for (var line in lines) {
          if (line.trim().isEmpty) continue;
          List<String> cells = parseCsvLine(line);

          if (cells.length >= 7) {
            String strData = cells[1].replaceAll('"', '').trim();
            String oraRitrovo = cells[3].replaceAll('"', '').trim();
            String indirizzo = cells[4].replaceAll('"', '').trim();
            String ospitante = cells[5].replaceAll('"', '').trim();
            String ospite = cells[6].replaceAll('"', '').trim();

            try {
              DateFormat format = DateFormat("dd-MM-yyyy");
              DateTime dataPartita = format.parse(strData);

              tempPartite.add(Partita(
                data: dataPartita,
                dataStringa: strData,
                squadraOspitante: ospitante,
                squadraOspite: ospite,
                indirizzo: indirizzo,
                oraRitrovo: oraRitrovo,
              ));
            } catch (_) {
              // Salta l'intestazione o righe con date non valide
            }
          }
        }

        // Calcola l'indice della prima partita con data >= oggi
        int prossimaIndex = tempPartite.indexWhere((p) =>
            p.data.isAfter(soloOggi) || p.data.isAtSameMomentAs(soloOggi));

        setState(() {
          partite = tempPartite;
          caricamento = false;
          indiceProssimaPartita = prossimaIndex;
          if (prossimaIndex != -1) {
            partitaSelezionata = tempPartite[prossimaIndex];
          }
        });

        // Esegue lo scroll automatico verso la partita evidenziata
        if (prossimaIndex > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollController.animateTo(
              prossimaIndex * 72.0, // Altezza stimata dell'elemento
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
            );
          });
        }
      }
    } catch (e) {
      setState(() => caricamento = false);
    }
  }

  void confermaSelezione() {
    if (partitaSelezionata != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaginaGiocatori(partita: partitaSelezionata!),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona una partita per proseguire')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Partite da giocare")),
      body: caricamento
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: confermaSelezione,
                      icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                      label: const Text(
                        "CONFERMA PARTITA",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: partite.length,
                    itemBuilder: (context, index) {
                      final p = partite[index];
                      final bool isProssima = (index == indiceProssimaPartita);

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isProssima ? Colors.blue.shade50 : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isProssima
                              ? Border.all(color: Colors.blue.shade600, width: 2)
                              : Border.all(color: Colors.grey.shade300, width: 0.5),
                        ),
                        child: RadioListTile<Partita>(
                          title: Row(
                            children: [
                              Text(
                                p.dataStringa,
                                style: TextStyle(
                                  fontWeight: isProssima ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              if (isProssima) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade700,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    "PROSSIMA PARTITA",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            "${p.squadraOspitante} vs ${p.squadraOspite}",
                            style: TextStyle(
                              color: isProssima ? Colors.blue.shade900 : Colors.black87,
                            ),
                          ),
                          value: p,
                          groupValue: partitaSelezionata,
                          onChanged: (Partita? val) {
                            setState(() {
                              partitaSelezionata = val;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

// --- PAGINA 2: Selezione Giocatori ---
class PaginaGiocatori extends StatefulWidget {
  final Partita partita;
  const PaginaGiocatori({super.key, required this.partita});

  @override
  State<PaginaGiocatori> createState() => _PaginaGiocatoriState();
}

class _PaginaGiocatoriState extends State<PaginaGiocatori> {
  List<Giocatore> giocatori = [];
  bool caricamento = true;
  bool selezionaTutti = true;

  @override
  void initState() {
    super.initState();
    caricaGiocatori();
  }

  Future<void> caricaGiocatori() async {
    try {
      final response = await http.get(Uri.parse(urlTabellaGiocatori));
      if (response.statusCode == 200) {
        List<String> lines = response.body.split(RegExp(r'\r?\n'));
        List<Giocatore> tempGiocatori = [];

        for (var line in lines) {
          if (line.trim().isEmpty) continue;
          List<String> cells = parseCsvLine(line);

          if (cells.length >= 2) {
            String cognome = cells[0].replaceAll('"', '').trim();
            String nome = cells[1].replaceAll('"', '').trim();

            if (cognome.isNotEmpty &&
                nome.isNotEmpty &&
                cognome.toLowerCase() != 'cognome' &&
                nome.toLowerCase() != 'nome') {
              tempGiocatori.add(Giocatore(cognome: cognome, nome: nome));
            }
          }
        }

        setState(() {
          giocatori = tempGiocatori;
          caricamento = false;
        });
      }
    } catch (e) {
      setState(() => caricamento = false);
    }
  }

  void toggleSelezionaTutti(bool? valore) {
    bool nuovoStato = valore ?? false;
    setState(() {
      selezionaTutti = nuovoStato;
      for (var g in giocatori) {
        g.convocato = nuovoStato;
      }
    });
  }

  Future<void> inviaSuWhatsApp() async {
    List<String> convocati = giocatori
        .where((g) => g.convocato)
        .map((g) => "${g.cognome} ${g.nome}")
        .toList();

    String elencoTesto = convocati.join("\n");

    String messaggio =
        "In data *${widget.partita.dataStringa}* si giocherà la partita tra *${widget.partita.squadraOspitante}* e *${widget.partita.squadraOspite}* presso il campo che si trova a questo *indirizzo*: ${widget.partita.indirizzo}.\n"
        "Il ritrovo è direttamente al campo alle ore *${widget.partita.oraRitrovo}*\n\n"
        "*Convocati*:\n$elencoTesto";

    await Clipboard.setData(ClipboardData(text: messaggio));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Messaggio copiato negli appunti! Aprendo WhatsApp...'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    Uri url = Uri.parse("https://wa.me/?text=${Uri.encodeComponent(messaggio)}");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile aprire WhatsApp')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Giocatori")),
      body: caricamento
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    "Seleziona i giocatori convocati e premi il bottone 'Convoca'",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: inviaSuWhatsApp,
                      icon: const Icon(Icons.send, color: Colors.white),
                      label: const Text(
                        "CONVOCA (INVIA SU WHATSAPP)",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                CheckboxListTile(
                  title: const Text(
                    "Seleziona tutti",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  value: selezionaTutti,
                  onChanged: toggleSelezionaTutti,
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: giocatori.length,
                    itemBuilder: (context, index) {
                      final g = giocatori[index];
                      return CheckboxListTile(
                        title: Text("${g.cognome} ${g.nome}"),
                        value: g.convocato,
                        onChanged: (bool? val) {
                          setState(() {
                            g.convocato = val ?? false;
                            selezionaTutti = giocatori.every((giocatore) => giocatore.convocato);
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}