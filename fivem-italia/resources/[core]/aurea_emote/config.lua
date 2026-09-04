--[[
    AUREA · Emote — configurazione

    Tre famiglie:
      EMOTE      animazioni singole, alcune con un oggetto in mano
      CONDIVISE  richiedono il consenso di un'altra persona
      ANDATURE   il modo in cui il personaggio cammina
]]

EMO = {}

-- ---------------------------------------------------------------------------
--  Emote singole
--  ciclica = resta finché non la si annulla
--  oggetto = { modello, osso, posizione, rotazione }
-- ---------------------------------------------------------------------------
EMO.Emote = {

    -- ===================== POSTURE =====================
    sedere      = { categoria = 'posture', nome = 'Siediti a terra',   dizionario = 'timetable@ron@ig_5_p3', anim = 'ig_5_p3_base', ciclica = true },
    sdraiare    = { categoria = 'posture', nome = 'Sdraiati',          dizionario = 'amb@world_human_sunbathe@male@back@base', anim = 'base', ciclica = true },
    ginocchio   = { categoria = 'posture', nome = 'In ginocchio',      dizionario = 'amb@code_human_police_investigate@idle_a', anim = 'idle_a', ciclica = true },
    appoggiare  = { categoria = 'posture', nome = 'Appoggiati al muro', dizionario = 'amb@world_human_leaning@male@wall@back@idle_a', anim = 'idle_a', ciclica = true },
    braccia     = { categoria = 'posture', nome = 'Braccia conserte',  dizionario = 'amb@world_human_hang_out_street@male_c@idle_a', anim = 'idle_a', ciclica = true },
    mani_tasche = { categoria = 'posture', nome = 'Mani in tasca',     dizionario = 'amb@world_human_hang_out_street@male_a@idle_a', anim = 'idle_a', ciclica = true },
    riposo      = { categoria = 'posture', nome = 'Sull\'attenti',     dizionario = 'amb@world_human_guard_stand@male@idle_a', anim = 'idle_a', ciclica = true },
    mani_alto   = { categoria = 'posture', nome = 'Mani in alto',      dizionario = 'random@mugging3', anim = 'handsup_standing_base', ciclica = true },
    inginocchiato_mani = { categoria = 'posture', nome = 'In ginocchio, mani in testa', dizionario = 'random@arrests@busted', anim = 'idle_a', ciclica = true },

    -- ===================== GESTI =====================
    salutare    = { categoria = 'gesti', nome = 'Saluta',           dizionario = 'friends@fra@ig_1', anim = 'over_here_idle_a' },
    applaudire  = { categoria = 'gesti', nome = 'Applaudi',         dizionario = 'anim@mp_player_intcelebrationmale@slow_clap', anim = 'slow_clap' },
    indicare    = { categoria = 'gesti', nome = 'Indica',           dizionario = 'anim@mp_point', anim = 'idle', ciclica = true },
    annuire     = { categoria = 'gesti', nome = 'Annuisci',         dizionario = 'gestures@m@standing@casual', anim = 'gesture_nod_yes_soft' },
    negare      = { categoria = 'gesti', nome = 'Scuoti la testa',  dizionario = 'gestures@m@standing@casual', anim = 'gesture_shrug_hard' },
    spallucce   = { categoria = 'gesti', nome = 'Fai spallucce',    dizionario = 'gestures@m@standing@casual', anim = 'gesture_shrug_soft' },
    calmare     = { categoria = 'gesti', nome = 'Calma',            dizionario = 'gestures@m@standing@casual', anim = 'gesture_easy_now' },
    pensare     = { categoria = 'gesti', nome = 'Rifletti',         dizionario = 'amb@world_human_stand_impatient@male@no_sign@base', anim = 'base', ciclica = true },
    facepalm    = { categoria = 'gesti', nome = 'Mano in faccia',   dizionario = 'anim@mp_player_intcelebrationmale@face_palm', anim = 'face_palm' },
    esultare    = { categoria = 'gesti', nome = 'Esulta',           dizionario = 'anim@mp_player_intcelebrationmale@rock', anim = 'rock' },

    -- ===================== LAVORO =====================
    scrivere    = { categoria = 'lavoro', nome = 'Prendi appunti',  dizionario = 'amb@world_human_clipboard@male@idle_a', anim = 'idle_c', ciclica = true,
                    oggetto = { modello = 'prop_notepad_01', osso = 18905, pos = { 0.1, 0.02, 0.05 }, rot = { -130.0, -50.0, 0.0 } } },
    telefonare  = { categoria = 'lavoro', nome = 'Al telefono',     dizionario = 'cellphone@', anim = 'cellphone_call_listen_base', ciclica = true,
                    oggetto = { modello = 'prop_npc_phone_02', osso = 28422, pos = { 0.0, 0.0, 0.0 }, rot = { 0.0, 0.0, 0.0 } } },
    tablet      = { categoria = 'lavoro', nome = 'Consulta il tablet', dizionario = 'amb@world_human_seat_wall_tablet@female@base', anim = 'base', ciclica = true,
                    oggetto = { modello = 'prop_cs_tablet', osso = 28422, pos = { 0.0, 0.0, 0.03 }, rot = { 0.0, 0.0, 0.0 } } },
    martellare  = { categoria = 'lavoro', nome = 'Martella',        dizionario = 'amb@world_human_hammering@male@base', anim = 'base', ciclica = true },
    riparare    = { categoria = 'lavoro', nome = 'Ripara',          dizionario = 'mini@repair', anim = 'fixing_a_ped', ciclica = true },
    spazzare    = { categoria = 'lavoro', nome = 'Spazza',          dizionario = 'amb@world_human_janitor@male@idle_a', anim = 'idle_a', ciclica = true },
    saldare     = { categoria = 'lavoro', nome = 'Salda',           dizionario = 'amb@world_human_welding@male@base', anim = 'base', ciclica = true },
    zappare     = { categoria = 'lavoro', nome = 'Lavora la terra', dizionario = 'amb@world_human_gardener_plant@male@base', anim = 'base', ciclica = true },
    cucinare    = { categoria = 'lavoro', nome = 'Cucina',          dizionario = 'amb@prop_human_bbq@male@base', anim = 'base', ciclica = true },
    visitare    = { categoria = 'lavoro', nome = 'Visita medica',   dizionario = 'amb@medic@standing@kneel@base', anim = 'base', ciclica = true },
    fotografare = { categoria = 'lavoro', nome = 'Scatta una foto', dizionario = 'amb@world_human_paparazzi@male@base', anim = 'base', ciclica = true,
                    oggetto = { modello = 'prop_pap_camera_01', osso = 28422, pos = { 0.0, 0.0, 0.0 }, rot = { 0.0, 0.0, 0.0 } } },
    perquisire  = { categoria = 'lavoro', nome = 'Perquisisci',     dizionario = 'anim@gangops@morgue@table@', anim = 'search_body', ciclica = true },

    -- ===================== VITA QUOTIDIANA =====================
    fumare      = { categoria = 'quotidiano', nome = 'Fuma',        dizionario = 'amb@world_human_smoking@male@male_a@base', anim = 'base', ciclica = true,
                    oggetto = { modello = 'prop_cs_ciggy_01', osso = 28422, pos = { 0.012, -0.005, 0.001 }, rot = { 80.0, 0.0, 100.0 } } },
    caffe       = { categoria = 'quotidiano', nome = 'Bevi un caffè', dizionario = 'amb@world_human_aa_coffee@base', anim = 'base', ciclica = true,
                    oggetto = { modello = 'p_amb_coffeecup_01', osso = 28422, pos = { 0.0, 0.0, 0.0 }, rot = { 0.0, 0.0, 0.0 } } },
    bere        = { categoria = 'quotidiano', nome = 'Bevi',        dizionario = 'amb@world_human_drinking@beer@male@idle_a', anim = 'idle_a', ciclica = true },
    mangiare    = { categoria = 'quotidiano', nome = 'Mangia',      dizionario = 'mp_player_inteat@burger', anim = 'mp_player_int_eat_burger' },
    leggere     = { categoria = 'quotidiano', nome = 'Leggi',       dizionario = 'amb@world_human_seat_wall@male@hands_by_side@base', anim = 'base', ciclica = true },
    stiracchiare= { categoria = 'quotidiano', nome = 'Stiracchiati', dizionario = 'amb@world_human_yoga@male@base', anim = 'base_a' },
    guardare_ora= { categoria = 'quotidiano', nome = 'Guarda l\'ora', dizionario = 'cellphone@', anim = 'cellphone_text_read_base' },
    ballare     = { categoria = 'quotidiano', nome = 'Balla',       dizionario = 'anim@amb@nightclub@dancers@solomun_entourage@', anim = 'mi_dance_facedj_17_v2_female^1', ciclica = true },
    saltare_gioia = { categoria = 'quotidiano', nome = 'Salta di gioia', dizionario = 'anim@mp_player_intcelebrationfemale@wank', anim = 'wank' },

    -- ===================== FORZE DELL'ORDINE =====================
    alt         = { categoria = 'servizio', nome = 'Segnala l\'alt', dizionario = 'amb@world_human_car_park_attendant@male@base', anim = 'base', ciclica = true },
    paletta     = { categoria = 'servizio', nome = 'Paletta segnaletica', dizionario = 'amb@world_human_car_park_attendant@male@base', anim = 'base', ciclica = true,
                    oggetto = { modello = 'prop_parking_wand_01', osso = 28422, pos = { 0.0, 0.0, 0.0 }, rot = { 0.0, 0.0, 0.0 } } },
    radio_serv  = { categoria = 'servizio', nome = 'Parla alla radio', dizionario = 'random@arrests', anim = 'generic_radio_chatter' },
    ammanettare = { categoria = 'servizio', nome = 'Ammanetta',     dizionario = 'mp_arrest_paired', anim = 'cop_p2_back_left' },
    rilievi     = { categoria = 'servizio', nome = 'Rilievi',       dizionario = 'amb@medic@standing@kneel@base', anim = 'base', ciclica = true },

    -- ===================== SEGNALI E VARIE =====================
    ok          = { categoria = 'varie', nome = 'Pollice in su',    dizionario = 'anim@mp_player_intcelebrationfemale@thumbs_up', anim = 'thumbs_up' },
    no_ok       = { categoria = 'varie', nome = 'Pollice in giù',   dizionario = 'anim@mp_player_intcelebrationfemale@thumbs_down', anim = 'thumbs_down' },
    inchino     = { categoria = 'varie', nome = 'Inchinati',        dizionario = 'anim@mp_player_intcelebrationfemale@bow', anim = 'bow' },
    arrendersi  = { categoria = 'varie', nome = 'Arrenditi',        dizionario = 'random@mugging3', anim = 'handsup_standing_base', ciclica = true },
    tremare     = { categoria = 'varie', nome = 'Trema dal freddo', dizionario = 'amb@world_human_stand_impatient@male@no_sign@base', anim = 'base', ciclica = true },
}

-- ---------------------------------------------------------------------------
--  Emote condivise: servono in due, e la seconda persona deve accettare
-- ---------------------------------------------------------------------------
EMO.Condivise = {
    stretta_mano = {
        nome = 'Stretta di mano', distanza = 1.6,
        promotore  = { dizionario = 'mp_ped_interaction', anim = 'handshake_guy_a' },
        invitato   = { dizionario = 'mp_ped_interaction', anim = 'handshake_guy_b' },
    },
    abbraccio = {
        nome = 'Abbraccio', distanza = 1.4,
        promotore  = { dizionario = 'mp_ped_interaction', anim = 'kisses_guy_a' },
        invitato   = { dizionario = 'mp_ped_interaction', anim = 'kisses_guy_b' },
    },
    cinque = {
        nome = 'Batti il cinque', distanza = 1.6,
        promotore  = { dizionario = 'anim@arena@celeb@flat@paired@no_props@', anim = 'high_five_a_player_a' },
        invitato   = { dizionario = 'anim@arena@celeb@flat@paired@no_props@', anim = 'high_five_a_player_b' },
    },
    trasporto = {
        nome = 'Porta in braccio', distanza = 1.4, attacca = true,
        promotore  = { dizionario = 'missfinale_c2mcs_1', anim = 'fin_c2_mcs_1_camman' },
        invitato   = { dizionario = 'nm', anim = 'firemans_carry' },
    },
}

-- ---------------------------------------------------------------------------
--  Andature
-- ---------------------------------------------------------------------------
EMO.Andature = {
    normale     = { nome = 'Normale',     set = nil },
    sicuro      = { nome = 'Sicuro di sé', set = 'move_m@confident' },
    spavaldo    = { nome = 'Spavaldo',    set = 'move_m@shadyped@a' },
    rilassato   = { nome = 'Rilassato',   set = 'move_m@casual@a' },
    frettoloso  = { nome = 'Frettoloso',  set = 'move_m@hurry@a' },
    stanco      = { nome = 'Stanco',      set = 'move_m@tough_guy@' },
    elegante    = { nome = 'Elegante',    set = 'move_f@sexy@a' },
    ferito      = { nome = 'Zoppicante',  set = 'move_m@injured' },
    ubriaco     = { nome = 'Barcollante', set = 'move_m@drunk@moderatedrunk' },
    autorevole  = { nome = 'Autorevole',  set = 'move_p_m_zero_slow' },
}

-- ---------------------------------------------------------------------------
--  Categorie per il menu
-- ---------------------------------------------------------------------------
EMO.Categorie = {
    { id = 'posture',    nome = 'Posture',           icona = '🧍' },
    { id = 'gesti',      nome = 'Gesti',             icona = '👋' },
    { id = 'lavoro',     nome = 'Lavoro',            icona = '🔧' },
    { id = 'quotidiano', nome = 'Vita quotidiana',   icona = '☕' },
    { id = 'servizio',   nome = 'Servizio',          icona = '🚔' },
    { id = 'varie',      nome = 'Varie',             icona = '✨' },
}

--- Emote di una categoria, ordinate per nome.
function EMO.PerCategoria(categoria)
    local out = {}
    for id, e in pairs(EMO.Emote) do
        if e.categoria == categoria then
            out[#out + 1] = { id = id, dati = e }
        end
    end
    table.sort(out, function(a, b) return a.dati.nome < b.dati.nome end)
    return out
end
