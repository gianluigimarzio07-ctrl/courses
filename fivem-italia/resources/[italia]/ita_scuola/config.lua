--[[
    AUREA · Università e titoli di studio — configurazione

    C'era una cosa che stonava: chiunque poteva farsi assumere come medico
    o come avvocato. Il grado esisteva, il permesso esisteva, e bastava che
    un titolare cliccasse "assumi". In un server che ha il codice penale
    con gli articoli giusti, il medico senza laurea è una stonatura.

    Questa risorsa mette in mezzo il titolo di studio, e prova a farlo
    senza trasformarlo in un muro noioso.

    COME FUNZIONA

    Ci si iscrive a un corso, si pagano le tasse, e si sostengono gli esami
    uno alla volta. Ogni esame è un quiz breve sulla materia. Fra un esame
    e l'altro c'è una pausa — la "sessione" — perché una laurea presa in
    quattro minuti non vale niente e perché il tempo di gioco è la sola
    valuta che non si può comprare.

    Finiti gli esami arriva la laurea. Per medico e avvocato non basta: ci
    vuole l'esame di Stato, che è una seconda prova più dura. È così anche
    nella realtà, e qui serve a distinguere chi ha studiato da chi ha
    studiato e poi ha voluto davvero fare quel mestiere.

    L'ALTERNATIVA HONESTA

    Se un server non vuole questo attrito, SCU.Obbligatorio si mette a
    false e i titoli restano una cosa che si può avere ma che nessuno
    controlla. Meglio un interruttore dichiarato che un sistema che ognuno
    aggira come gli pare.
]]

SCU = {}

--- Se false, i titoli si possono conseguire ma nessun lavoro li richiede.
SCU.Obbligatorio = true

-- ---------------------------------------------------------------------------
--  Sedi
-- ---------------------------------------------------------------------------
SCU.Sedi = {
    {
        id = 'ateneo',
        nome = 'Università degli Studi',
        segreteria = vector3(-1655.4, 187.2, 61.4),
        aula = vector3(-1642.0, 179.6, 61.4),
        blip = { sprite = 408, colore = 38, scala = 0.85 },
    },
    {
        id = 'ordini',
        nome = 'Palazzo degli Ordini professionali',
        segreteria = vector3(-544.2, -190.6, 38.2),
        aula = vector3(-537.1, -196.4, 38.2),
        blip = { sprite = 408, colore = 5, scala = 0.75 },
    },
}

-- ---------------------------------------------------------------------------
--  Corsi di laurea
--
--  Ogni esame ha una materia e un pacchetto di domande. Il numero di esami
--  è la vera durata del corso: medicina è lunga perché deve esserlo.
-- ---------------------------------------------------------------------------
SCU.Corsi = {
    {
        id = 'medicina',
        nome = 'Medicina e Chirurgia',
        titolo = 'Laurea in Medicina e Chirurgia',
        tasse = 145000,
        sede = 'ateneo',
        -- Il titolo abilita a questi lavori, se SCU.Obbligatorio
        abilita = { '118', 'medico' },
        -- Serve anche l'esame di Stato per esercitare
        esameDiStato = true,
        esami = { 'anatomia', 'farmacologia', 'medicina_urgenza', 'medicina_legale' },
    },
    {
        id = 'giurisprudenza',
        nome = 'Giurisprudenza',
        titolo = 'Laurea in Giurisprudenza',
        tasse = 118000,
        sede = 'ateneo',
        abilita = { 'avvocato', 'giudice' },
        esameDiStato = true,
        esami = { 'diritto_penale', 'procedura_penale', 'diritto_civile' },
    },
    {
        id = 'economia',
        nome = 'Economia e Commercio',
        titolo = 'Laurea in Economia',
        tasse = 96000,
        sede = 'ateneo',
        abilita = { 'agenzia_entrate' },
        esami = { 'diritto_tributario', 'ragioneria' },
    },
    {
        id = 'ingegneria',
        nome = 'Ingegneria civile',
        titolo = 'Laurea in Ingegneria civile',
        tasse = 108000,
        sede = 'ateneo',
        abilita = {},
        esami = { 'scienza_costruzioni', 'sicurezza_cantieri' },
    },
    {
        id = 'giornalismo',
        nome = 'Scienze della comunicazione',
        titolo = 'Laurea in Scienze della comunicazione',
        tasse = 78000,
        sede = 'ateneo',
        abilita = { 'giornalista' },
        esami = { 'diritto_informazione' },
    },
}

-- ---------------------------------------------------------------------------
--  Gli esami
--
--  Le risposte non lasciano mai il server: al client vanno le domande e le
--  alternative mescolate, la correzione la fa il server.
-- ---------------------------------------------------------------------------
SCU.Materie = {
    anatomia = {
        nome = 'Anatomia umana',
        domande = {
            { d = 'L\'arteria femorale si comprime per arrestare un\'emorragia:',
              o = { 'All\'inguine, contro il ramo pubico', 'Al polso', 'Alla clavicola', 'Al collo' }, g = 1 },
            { d = 'Quante costole ha in totale un adulto normoconformato?',
              o = { '24', '20', '26', '22' }, g = 1 },
            { d = 'Il polso radiale si rileva:',
              o = { 'Al lato del pollice, sulla faccia anteriore del polso',
                    'Sul dorso della mano', 'All\'incavo del gomito', 'Dietro il ginocchio' }, g = 1 },
        },
    },
    farmacologia = {
        nome = 'Farmacologia',
        domande = {
            { d = 'L\'adrenalina in emergenza si somministra per:',
              o = { 'Shock anafilattico e arresto cardiaco', 'Febbre alta', 'Frattura esposta', 'Ustione lieve' }, g = 1 },
            { d = 'Un farmaco “da banco” è:',
              o = { 'Vendibile senza ricetta', 'Vendibile solo in ospedale',
                    'Riservato ai veterinari', 'Sempre stupefacente' }, g = 1 },
            { d = 'Le sostanze della tabella I del DPR 309/90 sono:',
              o = { 'Stupefacenti a maggior potere tossicomanigeno',
                    'Integratori alimentari', 'Farmaci da banco', 'Disinfettanti' }, g = 1 },
        },
    },
    medicina_urgenza = {
        nome = 'Medicina d\'urgenza',
        domande = {
            { d = 'In un triage di pronto soccorso, il codice rosso indica:',
              o = { 'Compromissione delle funzioni vitali', 'Nessuna urgenza',
                    'Urgenza differibile', 'Solo richiesta di certificato' }, g = 1 },
            { d = 'Il rapporto compressioni/ventilazioni nella rianimazione dell\'adulto è:',
              o = { '30 a 2', '15 a 2', '5 a 1', '10 a 1' }, g = 1 },
            { d = 'Davanti a un\'emorragia arteriosa massiva l\'azione immediata è:',
              o = { 'Compressione diretta della ferita', 'Somministrare acqua',
                    'Sollevare le gambe', 'Attendere l\'ambulanza senza toccare' }, g = 1 },
        },
    },
    medicina_legale = {
        nome = 'Medicina legale',
        domande = {
            { d = 'L\'obbligo di referto del sanitario è previsto da:',
              o = { 'Art. 365 c.p.', 'Art. 110 c.p.', 'Art. 40 Cost.', 'Art. 2043 c.c.' }, g = 1 },
            { d = 'Il riscontro diagnostico serve a:',
              o = { 'Stabilire la causa della morte', 'Rilasciare un certificato di idoneità',
                    'Valutare l\'invalidità civile', 'Autorizzare un trapianto' }, g = 1 },
            { d = 'Il segreto professionale del medico può essere derogato:',
              o = { 'Quando c\'è obbligo di referto o denuncia', 'Mai',
                    'Su richiesta di chiunque', 'Solo con il consenso del datore di lavoro' }, g = 1 },
        },
    },
    diritto_penale = {
        nome = 'Diritto penale',
        domande = {
            { d = 'L\'art. 575 c.p. punisce:',
              o = { 'L\'omicidio', 'Il furto', 'La truffa', 'L\'evasione' }, g = 1 },
            { d = 'La differenza fra rapina (art. 628) e furto (art. 624) sta:',
              o = { 'Nella violenza o minaccia alla persona', 'Nel valore della refurtiva',
                    'Nell\'ora del fatto', 'Nel numero degli autori' }, g = 1 },
            { d = 'L\'associazione di tipo mafioso è punita dall\'articolo:',
              o = { '416-bis c.p.', '416 c.p.', '648-bis c.p.', '629 c.p.' }, g = 1 },
        },
    },
    procedura_penale = {
        nome = 'Procedura penale',
        domande = {
            { d = 'Il patteggiamento comporta una riduzione della pena fino a:',
              o = { 'Un terzo', 'La metà', 'Due terzi', 'Nessuna riduzione' }, g = 1 },
            { d = 'Il difensore può conferire con l\'arrestato:',
              o = { 'Subito, senza autorizzazione preventiva (art. 104 c.p.p.)',
                    'Solo dopo trenta giorni', 'Solo con il consenso del pubblico ministero',
                    'Mai prima del processo' }, g = 1 },
            { d = 'Il rito abbreviato si svolge:',
              o = { 'Allo stato degli atti, senza dibattimento',
                    'Con giuria popolare', 'Sempre in appello', 'Solo per le contravvenzioni' }, g = 1 },
        },
    },
    diritto_civile = {
        nome = 'Diritto civile',
        domande = {
            { d = 'La comunione dei beni fra coniugi comporta che gli acquisti fatti dopo il matrimonio:',
              o = { 'Siano di entrambi', 'Restino di chi li fa',
                    'Vadano allo Stato', 'Siano indivisibili per legge' }, g = 1 },
            { d = 'Il risarcimento del danno extracontrattuale è previsto da:',
              o = { 'Art. 2043 c.c.', 'Art. 575 c.p.', 'Art. 1 Cost.', 'Art. 186 CdS' }, g = 1 },
        },
    },
    diritto_tributario = {
        nome = 'Diritto tributario',
        domande = {
            { d = 'L\'IRPEF è un\'imposta:',
              o = { 'Progressiva per scaglioni', 'Proporzionale fissa',
                    'Regressiva', 'Applicata solo alle imprese' }, g = 1 },
            { d = 'L\'aliquota IVA ordinaria in Italia è:',
              o = { '22%', '10%', '4%', '20%' }, g = 1 },
        },
    },
    ragioneria = {
        nome = 'Ragioneria generale',
        domande = {
            { d = 'Il regime forfettario si caratterizza per:',
              o = { 'Un\'imposta sostitutiva su un reddito calcolato a coefficiente',
                    'L\'esenzione totale da imposte', 'L\'obbligo di bilancio consolidato',
                    'L\'IVA al 4% su tutto' }, g = 1 },
            { d = 'Una fattura emessa e non incassata alla scadenza diventa:',
              o = { 'Insoluta', 'Stornata', 'Pagata', 'Nulla' }, g = 1 },
        },
    },
    scienza_costruzioni = {
        nome = 'Scienza delle costruzioni',
        domande = {
            { d = 'Il calcestruzzo armato resiste bene a compressione grazie al calcestruzzo e a trazione grazie:',
              o = { 'All\'acciaio delle armature', 'Alla sabbia', 'All\'acqua d\'impasto', 'Al legno delle casseforme' }, g = 1 },
            { d = 'Un solaio va dimensionato principalmente sui:',
              o = { 'Carichi permanenti e accidentali', 'Colori della facciata',
                    'Costi di trasporto', 'Tempi di consegna' }, g = 1 },
        },
    },
    sicurezza_cantieri = {
        nome = 'Sicurezza nei cantieri',
        domande = {
            { d = 'Il testo unico sulla sicurezza sul lavoro è:',
              o = { 'D.Lgs. 81/2008', 'D.Lgs. 231/2001', 'L. 300/1970', 'D.P.R. 380/2001' }, g = 1 },
            { d = 'Sopra i due metri di altezza è obbligatorio:',
              o = { 'Il dispositivo anticaduta o il parapetto', 'Il casco soltanto',
                    'Nulla di particolare', 'Il patentino da gruista' }, g = 1 },
        },
    },
    diritto_informazione = {
        nome = 'Diritto dell\'informazione',
        domande = {
            { d = 'La diffamazione a mezzo stampa è aggravata dall\'articolo:',
              o = { '595 c.3 c.p.', '594 c.p.', '416 c.p.', '640 c.p.' }, g = 1 },
            { d = 'La rettifica prevista dall\'art. 8 della legge 47/1948 va pubblicata:',
              o = { 'Senza commento e con lo stesso rilievo',
                    'A pagamento del richiedente', 'Solo se lo decide il direttore',
                    'Entro sei mesi' }, g = 1 },
        },
    },
}

-- ---------------------------------------------------------------------------
--  Regole d'esame
-- ---------------------------------------------------------------------------
SCU.Regole = {
    -- Quante domande per esame e quanti errori si perdonano
    domandePerEsame = 3,
    erroriAmmessi = 0,

    -- Minuti fra un esame e il successivo: è la "sessione"
    minutiFraEsami = 25,
    -- Chi viene bocciato aspetta di più prima di riprovare
    minutiDopoBocciatura = 40,

    -- Tassa per ogni esame, oltre alle tasse d'iscrizione
    tassaEsame = 4500,
}

-- ---------------------------------------------------------------------------
--  Esame di Stato
--
--  Per medicina e giurisprudenza. Più lungo, e si paga.
-- ---------------------------------------------------------------------------
SCU.EsameDiStato = {
    sede = 'ordini',
    domande = 6,
    erroriAmmessi = 1,
    tassa = 62000,
    minutiRiprova = 60,
    -- L'iscrizione all'albo è il documento che poi conta
    item = 'tesserino',
}

-- ---------------------------------------------------------------------------
--  Utilità
-- ---------------------------------------------------------------------------
function SCU.GetCorso(id)
    for _, c in ipairs(SCU.Corsi) do
        if c.id == id then return c end
    end
    return nil
end

function SCU.GetSede(id)
    for _, s in ipairs(SCU.Sedi) do
        if s.id == id then return s end
    end
    return nil
end

function SCU.GetMateria(id) return SCU.Materie[id] end

--- Il corso che abilita a un dato lavoro, se ce n'è uno.
function SCU.CorsoPerLavoro(lavoro)
    for _, c in ipairs(SCU.Corsi) do
        for _, l in ipairs(c.abilita) do
            if l == lavoro then return c end
        end
    end
    return nil
end
