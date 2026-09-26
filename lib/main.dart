import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import per gestire la Clipboard
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

const String urlTabellaPartite = 'https://docs.google.com/spreadsheets/d/e/2PACX-1vTA-oDFCDZIShzqfWXWlxsl1UZjQnlJrR3nmg6c82n9jBFKv5VHb3_RDLUQCAxQpZpJZDki4vVGPdbq/pub?gid=0&single=true&output=csv';
const String urlTabellaGiocatori = 'https://docs.google.com/spreadsheets/d/e/2PACX-1vTA-oDFCDZIShzqfWXWlxsl1UZjQnlJrR3nmg6c82n9jBFKv5VHb3_RDLUQCAxQpZpJZDki4vVGPdbq/pub?gid=1093465003&single=true&output=csv';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestione Partite',
      theme: ThemeData(primarySwatch: Colors.blue),
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
  final String indirizzo; // Aggiunto campo per l'indirizzo

  Partita({
    required this.data,
    required this.dataStringa,
    required this.squadraOspitante,
    required this.squadraOspite,
    required this.indirizzo,
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

  @override
  void initState() {
    super.initState();
    caricaPartite();
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
            String strData = cells[1].replaceAll('"', '').trim(); // Colonna B (indice 1)
            String indirizzo = cells[4].replaceAll('"', '').trim(); // Colonna E (indice 4)
            String ospitante = cells[5].replaceAll('"', '').trim(); // Colonna F (indice 5)
            String ospite = cells[6].replaceAll('"', '').trim(); // Colonna G (indice 6)

            try {
              DateFormat format = DateFormat("dd-MM-yyyy");
              DateTime dataPartita = format.parse(strData);

              if (dataPartita.isAfter(soloOggi) || dataPartita.isAtSameMomentAs(soloOggi)) {
                tempPartite.add(Partita(
                  data: dataPartita,
                  dataStringa: strData,
                  squadraOspitante: ospitante,
                  squadraOspite: ospite,
                  indirizzo: indirizzo,
                ));
              }
            } catch (_) {
              // Salta l'intestazione o righe con date non valide
            }
          }
        }

        setState(() {
          partite = tempPartite;
          caricamento = false;
        });
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
      appBar: AppBar(title: const Text("partite da giocare")),
      body: caricamento
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: confermaSelezione,
                    child: const Text("Conferma Partita"),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: partite.length,
                    itemBuilder: (context, index) {
                      final p = partite[index];
                      return RadioListTile<Partita>(
                        title: Text("${p.dataStringa} - ${p.squadraOspitante} vs ${p.squadraOspite}"),
                        value: p,
                        groupValue: partitaSelezionata,
                        onChanged: (Partita? val) {
                          setState(() {
                            partitaSelezionata = val;
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
  bool selezionaTutti = true; // Stato del checkbox global "Seleziona tutti"

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
            String cognome = cells[0].replaceAll('"', '').trim(); // Colonna A
            String nome = cells[1].replaceAll('"', '').trim(); // Colonna B

            // Filtro per escludere l'intestazione e righe vuote
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

  // Funzione per selezionare o deselezionare tutti i giocatori
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
    
    // Nuovo formato del messaggio richiesto
    String messaggio =
        "In data ${widget.partita.dataStringa} si giocherà la partita tra ${widget.partita.squadraOspitante} e ${widget.partita.squadraOspite} presso il campo che si trova a questo indirizzo: ${widget.partita.indirizzo}.\n I convocati sono:\n$elencoTesto";

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
      appBar: AppBar(title: const Text("giocatori")),
      body: caricamento
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    "Seleziona i giocatori convocati e premi il bottone 'Convoca'",
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ElevatedButton(
                    onPressed: inviaSuWhatsApp,
                    child: const Text("Convoca"),
                  ),
                ),
                const Divider(height: 1),
                // Checkbox "Seleziona tutti"
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