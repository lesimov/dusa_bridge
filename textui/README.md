# Dusa Bridge - TextUI Module

Merkezi Text UI sistemi. NUI tabanlı InteractionPrompt component'i kullanarak oyunculara interaktif prompts gösterir.

## Özellikler

✅ **Standalone NUI** - dusa_bridge kendi NUI'sini hostlar, diğer resourceler bağımlı değil
✅ **Framework Agnostic** - Herhangi bir framework ile çalışır
✅ **Lightweight** - Vanilla JavaScript, harici dependency yok
✅ **Responsive** - 4 farklı pozisyon seçeneği
✅ **Smooth Animations** - CSS transitions ile akıcı animasyonlar

## Kullanım

### Basit Kullanım

```lua
-- Text UI göster
exports.dusa_bridge:ShowTextUI('Open Garage')

-- Text UI gizle
exports.dusa_bridge:HideTextUI()
```

### Gelişmiş Kullanım

```lua
-- Özelleştirilmiş seçeneklerle göster
exports.dusa_bridge:ShowTextUI('Press to interact', {
    key = 'E',              -- Gösterilecek tuş (varsayılan: 'E')
    position = 'left-center', -- Konum (varsayılan: 'left-center')
    active = false,          -- Aktif durumu (varsayılan: false)
    visible = true           -- Görünürlük (varsayılan: true)
})

-- Aktif duruma geçir (tuşa basıldığında animasyon)
exports.dusa_bridge:SetActiveTextUI()

-- Açık mı kontrol et
local isOpen = exports.dusa_bridge:IsTextUIOpen()

-- Metni güncelle (UI'yi yeniden açmadan)
exports.dusa_bridge:UpdateTextUIText('New text')

-- Konumu güncelle
exports.dusa_bridge:UpdateTextUIPosition('top-center')
```

## Pozisyon Seçenekleri

- `left-center` - Sol orta (varsayılan)
- `top-center` - Üst orta
- `right-center` - Sağ orta
- `bottom-center` - Alt orta

## Örnek: Zone Tabanlı Kullanım

```lua
local textUIShown = false

-- Zone'a girildiğinde
local function onEnter()
    if not textUIShown then
        exports.dusa_bridge:ShowTextUI('Open Garage', {
            key = 'E',
            position = 'left-center'
        })
        textUIShown = true
    end
end

-- Zone'dan çıkıldığında
local function onExit()
    if textUIShown then
        exports.dusa_bridge:HideTextUI()
        textUIShown = false
    end
end

-- Tuşa basıldığında
CreateThread(function()
    while true do
        Wait(0)
        if textUIShown and IsControlJustPressed(0, 51) then -- E tuşu
            -- Aktif animasyonu göster ve gizle
            exports.dusa_bridge:SetActiveTextUI()
            textUIShown = false

            -- İşleminizi yapın
            TriggerEvent('myevent:openGarage')
        end
    end
end)
```

## Export Fonksiyonları

| Export | Parametreler | Açıklama |
|--------|-------------|----------|
| `ShowTextUI` | `text: string, options?: table` | Text UI gösterir |
| `HideTextUI` | - | Text UI gizler |
| `SetActiveTextUI` | - | Aktif animasyonu tetikler ve UI'yi gizler |
| `IsTextUIOpen` | - | UI açık mı kontrol eder (boolean döner) |
| `UpdateTextUIText` | `text: string` | Gösterilen metni günceller |
| `UpdateTextUIPosition` | `position: string` | UI konumunu günceller |

## Framework Agnostic

Bu sistem tamamen framework-agnostic'tir ve herhangi bir FiveM resource'unda kullanılabilir. dusa_bridge'in yüklü ve çalışır durumda olması yeterlidir.

## NUI Mesajları

Sistem aşağıdaki NUI mesajlarını kullanır:

- `showInteractionPrompt` - Prompt'u gösterir
- `hideInteractionPrompt` - Prompt'u gizler
- `toggleInteractionPromptActive` - Aktif animasyonu tetikler
- `updateInteractionPromptText` - Metni günceller
- `updateInteractionPromptPosition` - Konumu günceller

Bu mesajlar otomatik olarak ilgili resource'un NUI'sine gönderilir.
