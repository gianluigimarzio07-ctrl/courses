--[[
    ESX su AUREA — ESX.UI.Menu

    È il pezzo che rompe più script se manca, perché mezzo ecosistema ESX
    apre i suoi menu così:

        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'garage', {
            title = 'Garage', align = 'top-left',
            elements = { { label = 'Auto', value = 'auto' } },
        }, function(dati, menu) ... end, function(dati, menu) menu.close() end)

    C'è una differenza di forma che va risolta con cura: il menu di ESX è a
    callback e non blocca, quello di aurea_ui è bloccante e restituisce la
    scelta. Il ponte apre il menu AUREA dentro un thread e poi richiama
    submit o cancel: chi chiama non si accorge di niente e continua a
    scrivere codice ESX.

    Una conseguenza da conoscere: in ESX il menu resta aperto finché non lo
    chiudi tu, e submit può scattare più volte. Qui il menu AUREA si chiude
    a ogni scelta, quindi dopo submit lo riapriamo da soli se il chiamante
    non l'ha chiuso. Il risultato osservabile è lo stesso.
]]

ESX.UI = {}
ESX.UI.Menu = {}
ESX.UI.Menu.RegisteredTypes = {}
ESX.UI.Menu.Opened = {}

local U = AUREA.Util

-- ---------------------------------------------------------------------------
--  Registrazione dei tipi
-- ---------------------------------------------------------------------------
function ESX.UI.Menu.RegisterType(tipo, apri, chiudi)
    ESX.UI.Menu.RegisteredTypes[tipo] = { open = apri, close = chiudi }
end

function ESX.UI.Menu.IsRegistered(tipo)
    return ESX.UI.Menu.RegisteredTypes[tipo] ~= nil
end

-- ---------------------------------------------------------------------------
--  Apertura
-- ---------------------------------------------------------------------------
function ESX.UI.Menu.Open(tipo, spazioNomi, nome, dati, alConferma, allAnnulla)
    local tipoRegistrato = ESX.UI.Menu.RegisteredTypes[tipo]

    if not tipoRegistrato then
        print(('[es_extended] ESX.UI.Menu.Open: tipo "%s" non registrato.'):format(tostring(tipo)))
        return nil
    end

    -- Un menu con lo stesso nome già aperto va sostituito, non affiancato
    ESX.UI.Menu.Close(tipo, spazioNomi, nome)

    local menu = {
        type = tipo,
        namespace = spazioNomi,
        name = nome,
        data = dati or {},
        submit = alConferma,
        cancel = allAnnulla,
        chiuso = false,
    }

    function menu.close()
        ESX.UI.Menu.Close(tipo, spazioNomi, nome)
    end

    function menu.update(chiave, valore)
        for _, elemento in ipairs(menu.data.elements or {}) do
            if elemento[chiave.key or 'value'] == (chiave.value or chiave) then
                for k, v in pairs(valore) do elemento[k] = v end
            end
        end
    end

    function menu.refresh()
        -- Il menu AUREA si ridisegna alla riapertura: qui basta segnare
        -- che al prossimo giro va riletto.
        menu.daRileggere = true
    end

    function menu.setElement(indice, chiave, valore)
        if menu.data.elements and menu.data.elements[indice] then
            menu.data.elements[indice][chiave] = valore
        end
    end

    function menu.setElements(elementi)
        menu.data.elements = elementi
    end

    function menu.setTitle(titolo)
        menu.data.title = titolo
    end

    ESX.UI.Menu.Opened[#ESX.UI.Menu.Opened + 1] = menu
    tipoRegistrato.open(spazioNomi, nome, dati, menu)

    return menu
end

function ESX.UI.Menu.Close(tipo, spazioNomi, nome)
    for i = #ESX.UI.Menu.Opened, 1, -1 do
        local m = ESX.UI.Menu.Opened[i]
        if m.type == tipo and m.namespace == spazioNomi and m.name == nome then
            m.chiuso = true
            local t = ESX.UI.Menu.RegisteredTypes[tipo]
            if t and t.close then t.close(spazioNomi, nome, m) end
            table.remove(ESX.UI.Menu.Opened, i)
        end
    end
end

function ESX.UI.Menu.CloseAll()
    for i = #ESX.UI.Menu.Opened, 1, -1 do
        local m = ESX.UI.Menu.Opened[i]
        m.chiuso = true
        local t = ESX.UI.Menu.RegisteredTypes[m.type]
        if t and t.close then t.close(m.namespace, m.name, m) end
        table.remove(ESX.UI.Menu.Opened, i)
    end
    exports.aurea_ui:ChiudiMenu()
end

function ESX.UI.Menu.GetOpened(tipo, spazioNomi, nome)
    for _, m in ipairs(ESX.UI.Menu.Opened) do
        if m.type == tipo and m.namespace == spazioNomi and m.name == nome then return m end
    end
    return nil
end

function ESX.UI.Menu.GetOpenedMenus()
    return ESX.UI.Menu.Opened
end

function ESX.UI.Menu.IsOpen(tipo, spazioNomi, nome)
    return ESX.UI.Menu.GetOpened(tipo, spazioNomi, nome) ~= nil
end

-- ---------------------------------------------------------------------------
--  Tipo 'default'
--
--  Il menu a elenco. Gli elementi ESX hanno label e value; alcuni hanno
--  anche type = 'slider' (con min, max, value) o sono puramente
--  informativi. Si rendono tutti come voci AUREA.
-- ---------------------------------------------------------------------------
ESX.UI.Menu.RegisterType('default', function(spazioNomi, nome, dati, menu)
    CreateThread(function()
        while not menu.chiuso do
            local voci = {}

            for indice, elemento in ipairs(menu.data.elements or {}) do
                local etichetta = elemento.label or elemento.name or tostring(elemento.value or indice)
                local descrizione = elemento.description or elemento.desc

                -- Gli slider ESX mostrano il valore corrente nell'etichetta
                if elemento.type == 'slider' then
                    descrizione = ('%s%d di %d — usa le frecce nel menu ESX originale')
                        :format(descrizione and (descrizione .. ' · ') or '',
                                elemento.value or elemento.min or 0, elemento.max or 0)
                end

                voci[#voci + 1] = {
                    id = tostring(indice),
                    icona = elemento.icona or '▸',
                    titolo = etichetta,
                    descrizione = descrizione,
                    disattivata = elemento.disabled == true,
                }
            end

            if #voci == 0 then
                voci[1] = { id = 'x', icona = '—', titolo = 'Nessuna voce', disattivata = true }
            end

            local scelta = exports.aurea_ui:Menu({
                titolo = menu.data.title or nome,
                sottotitolo = menu.data.subtitle,
                voci = voci,
            })

            if menu.chiuso then return end

            if not scelta or scelta == 'x' then
                menu.chiuso = true
                ESX.UI.Menu.Close('default', spazioNomi, nome)
                if menu.cancel then menu.cancel(menu.data, menu) end
                return
            end

            local elemento = (menu.data.elements or {})[tonumber(scelta)]
            if elemento and menu.submit then
                -- ESX passa l'elemento scelto con dentro current
                local pacchetto = {
                    current = elemento,
                    elements = menu.data.elements,
                    title = menu.data.title,
                }
                menu.submit(pacchetto, menu)
            end

            -- Se il chiamante non ha chiuso il menu, in ESX resterebbe
            -- aperto: qui si riapre al giro successivo del while.
            if menu.chiuso then return end
            Wait(50)
        end
    end)
end, function() end)

-- ---------------------------------------------------------------------------
--  Tipo 'dialog'
--
--  La finestrella con un campo di testo. Diventa un Dialogo AUREA a un
--  campo solo.
-- ---------------------------------------------------------------------------
ESX.UI.Menu.RegisterType('dialog', function(spazioNomi, nome, dati, menu)
    CreateThread(function()
        local risposte = exports.aurea_ui:Dialogo(menu.data.title or nome, {
            {
                etichetta = menu.data.title or 'Valore',
                tipo = 'text',
                segnaposto = menu.data.placeholder,
                obbligatorio = false,
            },
        })

        if menu.chiuso then return end
        menu.chiuso = true
        ESX.UI.Menu.Close('dialog', spazioNomi, nome)

        if risposte and risposte[1] ~= nil and tostring(risposte[1]) ~= '' then
            if menu.submit then menu.submit({ value = tostring(risposte[1]) }, menu) end
        else
            if menu.cancel then menu.cancel({}, menu) end
        end
    end)
end, function() end)

-- ---------------------------------------------------------------------------
--  Tipo 'list' (alias di default usato da qualche fork)
-- ---------------------------------------------------------------------------
ESX.UI.Menu.RegisterType('list',
    ESX.UI.Menu.RegisteredTypes['default'].open,
    ESX.UI.Menu.RegisteredTypes['default'].close)

-- ---------------------------------------------------------------------------
--  Chiusura di sicurezza
-- ---------------------------------------------------------------------------
AddEventHandler('onResourceStop', function(risorsa)
    if risorsa == GetCurrentResourceName() then
        for _, m in ipairs(ESX.UI.Menu.Opened) do m.chiuso = true end
        ESX.UI.Menu.Opened = {}
    end
end)
