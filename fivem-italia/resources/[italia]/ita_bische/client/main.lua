--[[
    AUREA · Bische clandestine (client)

    Il tavolo è un menu. Le carte arrivano una alla volta dal server e il
    client non ne conosce nessun'altra: non c'è un mazzo da leggere in
    memoria, perché il mazzo non è mai stato mandato.
]]

local aperte = {}

RegisterNetEvent('bis:aperte', function(elenco)
    aperte = {}
    for _, id in ipairs(elenco or {}) do aperte[id] = true end
end)

-- ---------------------------------------------------------------------------
--  Il tavolo
-- ---------------------------------------------------------------------------
local function gioca()
    CreateThread(function()
        local r = exports.aurea_ui:Dialogo('Sette e mezzo', {
            { etichetta = 'Quanto punti, in euro', tipo = 'number',
              min = math.floor(BIS.Tavolo.puntataMinima / 100),
              max = math.floor(BIS.Tavolo.puntataMassima / 100), obbligatorio = true },
        })
        if not r or not r[1] then return end

        local ok, esito = AUREA.Callback.Attendi('bis:punta', tonumber(r[1]))
        if not ok then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🃏',
                titolo = 'Tavolo', testo = tostring(esito), durata = 12000 })
        end

        local mano = { esito.carte[1] }
        local punti = esito.punti

        while true do
            local voci = {
                { id = 'x', disattivata = true, icona = '🃏',
                  titolo = ('Punti: %.1f'):format(punti),
                  descrizione = table.concat(mano, ' · ') },
                { id = 'carta', icona = '➕', titolo = 'Carta',
                  descrizione = ('Sopra %.1f si sballa.'):format(BIS.Regole.limite) },
                { id = 'sto', icona = '✋', titolo = 'Sto',
                  descrizione = 'Tira il banco. La parità la prende lui.' },
            }

            local scelta = exports.aurea_ui:Menu({
                titolo = 'Sette e mezzo', sottotitolo = 'Il re di denari vale quanto ti serve', voci = voci })
            if not scelta or scelta == 'x' then scelta = 'sto' end

            local ok2, e = AUREA.Callback.Attendi(scelta == 'carta' and 'bis:carta' or 'bis:sto')
            if not ok2 then
                return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🃏',
                    titolo = 'Tavolo', testo = tostring(e), durata = 12000 })
            end

            exports.aurea_ui:Notifica({
                tipo = e.finita and (e.vinto and 'successo' or 'errore') or 'info',
                icona = '🃏', titolo = 'Sette e mezzo', testo = e.messaggio, durata = 14000,
            })

            if e.finita then return end

            mano[#mano + 1] = e.carte[1]
            punti = e.punti
        end
    end)
end

-- ---------------------------------------------------------------------------
--  Apertura e banco
-- ---------------------------------------------------------------------------
local function apri(luogo)
    CreateThread(function()
        local r = exports.aurea_ui:Dialogo(('Apri la bisca — %s'):format(luogo.nome), {
            { etichetta = 'Banco in contanti, in euro', tipo = 'number',
              min = math.floor(BIS.Apertura.bancoMinimo / 100),
              max = math.floor(BIS.Apertura.bancoMassimo / 100), obbligatorio = true },
        })
        if not r or not r[1] then return end

        local ok, messaggio = AUREA.Callback.Attendi('bis:apri', luogo.id, tonumber(r[1]))
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🃏',
            titolo = 'Bisca', testo = tostring(messaggio), durata = 20000,
        })
    end)
end

local function pannello(luogo)
    CreateThread(function()
        if aperte[luogo.id] then
            local banco = AUREA.Callback.Attendi('bis:banco')
            local voci = { { id = 'gioca', icona = '🃏', titolo = 'Siediti al tavolo' } }

            if banco then
                voci[1] = { id = 'x', disattivata = true, icona = '💰',
                    titolo = ('Banco: %s'):format(AUREA.Util.Euro(banco.banco)),
                    descrizione = ('Ne avevi messi %s · %d mani · %d minuti alla chiusura')
                        :format(AUREA.Util.Euro(banco.iniziale), banco.mani, banco.minuti) }
                voci[#voci + 1] = { id = 'chiudi', icona = '🚪', titolo = 'Chiudi la serata',
                    descrizione = 'Il banco torna nelle tue tasche.' }
            end

            local scelta = exports.aurea_ui:Menu({
                titolo = luogo.nome, sottotitolo = 'Partita in corso', voci = voci })
            if scelta == 'gioca' then return gioca() end
            if scelta == 'chiudi' then return ExecuteCommand('chiudibisca') end
            return
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = luogo.nome,
            sottotitolo = 'Non c\'è nessuna partita, per adesso',
            voci = {
                { id = 'apri', icona = '🃏', titolo = 'Apri una bisca',
                  descrizione = ('Banco da %s in su, in contanti. Dura %d minuti. Art. 718 c.p.')
                      :format(AUREA.Util.Euro(BIS.Apertura.bancoMinimo), BIS.Apertura.durataMinuti) },
            },
        })
        if scelta == 'apri' then apri(luogo) end
    end)
end

-- ---------------------------------------------------------------------------
--  Punti di interazione
--
--  Nessun blip: una bisca che si trova sulla mappa non è una bisca.
-- ---------------------------------------------------------------------------
AddEventHandler('aurea:client:caricato', function()
    for _, l in ipairs(BIS.Luoghi) do
        exports.aurea_target:AggiungiZona('bisca_' .. l.id, l.coord, 3.0, {
            { etichetta = 'Retrobottega', icona = '🃏', azione = function() pannello(l) end },
        })
    end
end)
