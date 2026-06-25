function cloud_generation()
  % Zorgt ervoor dat het script altijd in zijn eigen map werkt, zodat plaatjes
  % zoals 'cloud_t8.jpg' altijd gevonden worden.
  script_dir = fileparts(mfilename('fullpath'));
  cd(script_dir);

  % We berekenen de schermgrootte om het venster netjes en gecentreerd neer te zetten.
  screensize = get(0, 'screensize')(3:4) / 1.5;

  N = 250;

  % Hier slaan we alle belangrijke simulatiegegevens op in een 'data' structuur.
  % Grootte van het raster (N x N cellen).
  data.N = N;

  % Houdt bij hoeveel generaties zijn berekend.
  data.generation = 0;

  % Geeft aan of de simulatie momenteel draait.
  data.active = false;

  % Visuele simulatiesnelheid in de hoofdloop.
  data.speed = 0.1;

  % Grootte van één tijdstap voor de numerieke berekeningen.
  data.dt = 0.01;

  % Achtergrondtemperatuur van het raster.
  data.T_bg = -3.0;

  % Beginsnelheid van de wind in m/s.
  data.wind_speed = 10.0;

  % Richting van de wind in graden.
  data.wind_angle = 90.0;

  % Bepaalt welke weergave wordt getoond.
  data.view_mode = 'thermal';

  % We kijken of er een satellietfoto in de map staat om mee te beginnen.
  % Zo niet, dan starten we met een leeg zwart canvas.
  if exist('cloud_t8.jpg', 'file')
    im = imread('cloud_t8.jpg');
    data.T_base = custom_resize(double(rgb2gray(im)) / 255, [N N]);
  else
    data.T_base = zeros(N, N);
  end

  % Deze parameters bepalen het gedrag van de wolken en de thermodynamica.
  % Dauwpunttemperatuur waarbij wolken kunnen ontstaan.
  data.params.Td = 2.0;

  % Toegestane afwijking rond het dauwpunt.
  data.params.delta = 0.5;

  % Celafstand in horizontale richting.
  data.params.dx = 1.0;

  % Celafstand in verticale richting.
  data.params.dy = 1.0;

  % Snelheid waarmee warmte zich verspreidt naar buurcellen.
  data.params.q = 0.003;

  % Initialiseerd het hoofdvenster
  FW = 1400;  FH = 900;
  data.fig = figure( ...
    'name',        'CLOUD CA  —  Silva et al. 2019', ...
    'numbertitle', 'off', ...
    'menubar',     'none', ...
    'color',       [0.1 0.1 0.1], ...
    'position',    [(screensize(1)-FW)/2 (screensize(2)-FH)/2 FW FH], ...
    'resize',      'off', ...
    'KeyPressFcn', @handle_key_input ...
  );

  % Waar we de cloud cellulaire simulatie op tekenen.
  data.axs = axes('units', 'pixels', 'position', [1 1 895 FH]);

  % Hieronder staan alle knoppen en sliders voor de interface.
  % De namen spreken voor zich.
  uicontrol('style', 'text', 'units', 'pixels', 'position', [905 862 490 33], ...
    'backgroundcolor', [0.1 0.1 0.1], 'foregroundcolor', [0.4 0.9 1.0], ...
    'string', 'CLOUD CA', 'fontsize', 24, 'fontweight', 'bold', ...
    'KeyPressFcn', @handle_key_input);

  data.gen_lbl = uicontrol('style', 'text', 'units', 'pixels', 'position', [905 828 490 30], ...
    'backgroundcolor', [0.3 0.3 0.3], 'foregroundcolor', [1.0 1.0 1.0], ...
    'string', 'Generation: 0', 'fontsize', 14, 'KeyPressFcn', @handle_key_input);

  data.wind_lbl = uicontrol('style', 'text', 'units', 'pixels', 'position', [905 788 490 40], ...
    'backgroundcolor', [0.2 0.2 0.2], 'foregroundcolor', [1.0 1.0 0.3], ...
    'string', 'Wind: -- deg', 'fontsize', 13, 'KeyPressFcn', @handle_key_input);

  data.play_btn = uicontrol('style', 'pushbutton', 'units', 'pixels', 'position', [905 674 490 107], ...
    'backgroundcolor', [0.0 0.7 0.0], 'foregroundcolor', [1.0 1.0 1.0], ...
    'string', '▶', 'fontsize', 80, 'callback', @play_sim, 'KeyPressFcn', @handle_key_input);

  data.restart_btn = uicontrol('style', 'pushbutton', 'units', 'pixels', 'position', [905 592 240 77], ...
    'backgroundcolor', [1.0 0.4 0.3], 'foregroundcolor', [1.0 1.0 1.0], ...
    'string', '↻  Restart', 'fontsize', 22, 'callback', @click_restart, 'KeyPressFcn', @handle_key_input);

  data.random_btn = uicontrol('style', 'pushbutton', 'units', 'pixels', 'position', [1149 592 246 77], ...
    'backgroundcolor', [0.5 0.2 0.8], 'foregroundcolor', [1.0 1.0 1.0], ...
    'string', '☁  Random', 'fontsize', 22, 'callback', @click_random, 'KeyPressFcn', @handle_key_input);

  data.load_btn = uicontrol('style', 'pushbutton', 'units', 'pixels', 'position', [905 510 240 77], ...
    'backgroundcolor', [0.1 0.5 0.1], 'foregroundcolor', [1.0 1.0 1.0], ...
    'string', '📁  Load', 'fontsize', 22, 'callback', @click_load, 'KeyPressFcn', @handle_key_input);

  data.save_btn = uicontrol('style', 'pushbutton', 'units', 'pixels', 'position', [1149 510 246 77], ...
    'backgroundcolor', [0.2 0.4 1.0], 'foregroundcolor', [1.0 1.0 1.0], ...
    'string', '💾  Save', 'fontsize', 22, 'callback', @click_save, 'KeyPressFcn', @handle_key_input);

  data.speed_lbl = uicontrol('style', 'text', 'units', 'pixels', 'position', [905 460 490 25], ...
    'backgroundcolor', [0.3 0.3 0.3], 'foregroundcolor', [1.0 1.0 1.0], ...
    'string', 'Speed: 10 g/s', 'fontsize', 12, 'KeyPressFcn', @handle_key_input);

  data.speed_sl = uicontrol('style', 'slider', 'units', 'pixels', 'position', [905 435 490 25], ...
    'backgroundcolor', [0.3 0.3 0.3], 'value', 10, 'min', 1, 'max', 120, 'sliderstep', [1/119 1/119], ...
    'callback', @speed_changed, 'KeyPressFcn', @handle_key_input);

  lbl_dt = uicontrol('style', 'text', 'units', 'pixels', 'position', [905 395 490 25], ...
    'backgroundcolor', [0.3 0.3 0.3], 'foregroundcolor', [1.0 1.0 1.0], ...
    'string', 'dt: 0.0100', 'fontsize', 12, 'KeyPressFcn', @handle_key_input);

  data.sl(1) = uicontrol('style', 'slider', 'units', 'pixels', 'position', [905 370 490 25], ...
    'backgroundcolor', [0.3 0.3 0.3], 'min', 0.001, 'max', 0.01, 'value', 0.010, ...
    'sliderstep', [0.01 0.1], 'callback', @(src,~) set(lbl_dt, 'string', sprintf('dt: %.4f', get(src,'value'))), ...
    'KeyPressFcn', @handle_key_input);

  lbl_tbg = uicontrol('style', 'text', 'units', 'pixels', 'position', [905 330 490 25], ...
    'backgroundcolor', [0.3 0.3 0.3], 'foregroundcolor', [1.0 1.0 1.0], ...
    'string', 'T_bg: -3.0 C', 'fontsize', 12, 'KeyPressFcn', @handle_key_input);

  data.sl(2) = uicontrol('style', 'slider', 'units', 'pixels', 'position', [905 305 490 25], ...
    'backgroundcolor', [0.3 0.3 0.3], 'min', -10, 'max', 0, 'value', -3.0, ...
    'sliderstep', [0.01 0.1], 'callback', @(src,~) set(lbl_tbg, 'string', sprintf('T_bg: %.1f C', get(src,'value'))), ...
    'KeyPressFcn', @handle_key_input);

  lbl_td = uicontrol('style', 'text', 'units', 'pixels', 'position', [905 265 490 25], ...
    'backgroundcolor', [0.3 0.3 0.3], 'foregroundcolor', [1.0 1.0 1.0], ...
    'string', 'Td: 2.0 C', 'fontsize', 12, 'KeyPressFcn', @handle_key_input);

  data.sl(3) = uicontrol('style', 'slider', 'units', 'pixels', 'position', [905 240 490 25], ...
    'backgroundcolor', [0.3 0.3 0.3], 'min', -5, 'max', 5, 'value', 2.0, ...
    'sliderstep', [0.01 0.1], 'callback', @(src,~) set(lbl_td, 'string', sprintf('Td: %.1f C', get(src,'value'))), ...
    'KeyPressFcn', @handle_key_input);

  lbl_q = uicontrol('style', 'text', 'units', 'pixels', 'position', [905 200 490 25], ...
    'backgroundcolor', [0.3 0.3 0.3], 'foregroundcolor', [1.0 1.0 1.0], ...
    'string', 'q: 0.0030', 'fontsize', 12, 'KeyPressFcn', @handle_key_input);

  data.sl(4) = uicontrol('style', 'slider', 'units', 'pixels', 'position', [905 175 490 25], ...
    'backgroundcolor', [0.3 0.3 0.3], 'min', 1e-4, 'max', 0.1, 'value', 0.003, ...
    'sliderstep', [0.01 0.1], 'callback', @(src,~) set(lbl_q, 'string', sprintf('q: %.4f', get(src,'value'))), ...
    'KeyPressFcn', @handle_key_input);

  lbl_wspd = uicontrol('style', 'text', 'units', 'pixels', 'position', [905 135 490 25], ...
    'backgroundcolor', [0.3 0.3 0.3], 'foregroundcolor', [1.0 1.0 1.0], ...
    'string', 'Wind speed: 10.0 m/s', 'fontsize', 12, 'KeyPressFcn', @handle_key_input);

  data.sl(5) = uicontrol('style', 'slider', 'units', 'pixels', 'position', [905 110 490 25], ...
    'backgroundcolor', [0.3 0.3 0.3], 'min', 0, 'max', 25, 'value', 10, ...
    'sliderstep', [0.01 0.1], 'callback', @(src,~) set(lbl_wspd, 'string', sprintf('Wind speed: %.1f m/s', get(src,'value'))), ...
    'KeyPressFcn', @handle_key_input);

  lbl_wang = uicontrol('style', 'text', 'units', 'pixels', 'position', [905 70 490 25], ...
    'backgroundcolor', [0.3 0.3 0.3], 'foregroundcolor', [1.0 1.0 1.0], ...
    'string', 'Wind angle: 60 deg', 'fontsize', 12, 'KeyPressFcn', @handle_key_input);

  data.sl(6) = uicontrol('style', 'slider', 'units', 'pixels', 'position', [905 45 490 25], ...
    'backgroundcolor', [0.3 0.3 0.3], 'min', 0, 'max', 360, 'value', 60, ...
    'sliderstep', [0.01 0.1], 'callback', @(src,~) set(lbl_wang, 'string', sprintf('Wind angle: %.0f deg', get(src,'value'))), ...
    'KeyPressFcn', @handle_key_input);

  data.help = uicontrol('style', 'pushbutton', 'units', 'pixels', 'position', [1350 10 40 40], ...
    'backgroundcolor', [0.3 0.5 1.0], 'foregroundcolor', [1.0 1.0 1.0], ...
    'string', '?', 'fontsize', 20, 'callback', @click_help, 'KeyPressFcn', @handle_key_input);

  data.switch_view = uicontrol('style', 'pushbutton', 'units', 'pixels', 'position', [10 845 40 40], ...
    'backgroundcolor', [0.9 0.3 0.3], 'foregroundcolor', [1.0 1.0 1.0], ...
    'string', '⇄', 'fontsize', 20, 'callback', @click_switch, 'KeyPressFcn', @handle_key_input);

  data.focus_dummy = uicontrol('style', 'pushbutton', 'units', 'pixels', 'position', [1 1 0 0], ...
    'backgroundcolor', [0.1 0.1 0.1], 'foregroundcolor', [0.1 0.1 0.1], ...
    'KeyPressFcn', @handle_key_input);

  % Hier tekenen we de image op het scherm
  data.params.T_buffer = 1.5;
  data = init_sim(data);
  data.img = imagesc(data.axs, data.T);
  colormap(data.axs, jet(256));
  caxis(data.axs, [data.T_bg, data.params.Td + data.params.T_buffer]);
  axis(data.axs, 'equal', 'off');

  guidata(data.fig, data);
end

% De daadwerkelijke code voor elke simulatiestap.
function [T_new, ux_new, uy_new, C_new] = ca_step(T, ux, uy, C, params, dt)

  % Afstand tussen twee cellen in het raster.
  % Deze waarden worden gebruikt bij het berekenen van afgeleiden.
  dx = params.dx;
  dy = params.dy;

  % We verschuiven de temperatuurmatrix in vier richtingen.
  % Hierdoor krijgt elke cel toegang tot haar linker-, rechter-,
  % boven- en onderbuur volgens de Von Neumann Neighborhood.
  T_l = circshift(T, [0, 1]); T_r = circshift(T, [0, -1]);
  T_u = circshift(T, [1, 0]); T_d = circshift(T, [-1, 0]);

  % Hetzelfde doen we voor de horizontale windsnelheid.
  % Hierdoor kunnen veranderingen in de wind worden berekend.
  ux_l = circshift(ux, [0, 1]); ux_r = circshift(ux, [0, -1]);
  ux_u = circshift(ux, [1, 0]); ux_d = circshift(ux, [-1, 0]);

  % Ook de verticale windsnelheid wordt verschoven.
  % Zo heeft iedere cel informatie over de wind van haar buren.
  uy_l = circshift(uy, [0, 1]); uy_r = circshift(uy, [0, -1]);
  uy_u = circshift(uy, [1, 0]); uy_d = circshift(uy, [-1, 0]);

  % Hier berekenen we de verandering van temperatuur en wind.
  % Hiervoor wordt een Upwind Scheme gebruikt zodat de simulatie
  % stabiel blijft en rekening houdt met de windrichting.
  dux_dx = (ux>0).*(ux-ux_l)./dx + (ux<=0).*(ux_r-ux)./dx;
  duy_dy = (uy>0).*(uy-uy_u)./dy + (uy<=0).*(uy_d-uy)./dy;
  dux_dy = (uy>0).*(ux-ux_u)./dy + (uy<=0).*(ux_d-ux)./dy;
  duy_dx = (ux>0).*(uy-uy_l)./dx + (ux<=0).*(uy_r-uy)./dx;

  % Temperatuurgradiënten in de x- en y-richting.
  % Deze bepalen hoe warmte door de wind wordt verplaatst.
  dT_dx  = (ux>0).*(T-T_l)./dx + (ux<=0).*(T_r-T)./dx;
  dT_dy  = (uy>0).*(T-T_u)./dy + (uy<=0).*(T_d-T)./dy;

  % Newton's afkoelingswet.
  % Warmere cellen geven warmte af aan koudere buurcellen,
  % waardoor temperatuurverschillen geleidelijk afnemen.
  dT_cool = -params.q .* (T - (T_l+T_r+T_u+T_d)./4);

  % Controleer of de temperatuur binnen het dauwpunt-interval valt.
  % Als dit zo is, wordt de cel als wolk gemarkeerd.
  C_new = (T >= (params.Td - params.delta)) & (T <= (params.Td + params.delta));

  % Euler-methode.
  % De berekende veranderingen worden toegepast op de huidige toestand
  % om de nieuwe temperatuur en windsnelheid te verkrijgen.
  ux_new = ux + (-ux.*dux_dx - uy.*duy_dy).*dt;
  uy_new = uy + (-ux.*duy_dx - uy.*duy_dy).*dt;

  % Temperatuur verandert door windtransport én afkoeling.
  % Samen bepalen deze processen de nieuwe temperatuurverdeling.
  T_new  = T + (-ux.*dT_dx - uy.*dT_dy + dT_cool).*dt;
end


function play_sim(source, event)
  clear_focus(source);
  data = guidata(source);
  data.active = ~data.active;
  guidata(source, data);

  if data.active
    set(data.play_btn, 'fontsize', 36, 'string', '▐▐ ', 'backgroundcolor', [0.7 0.0 0.0]);
  else
    set(data.play_btn, 'fontsize', 80, 'string', '▶', 'backgroundcolor', [0.0 0.7 0.0]);
  end

  % De hoofd-simulatie loop.
  while data.active
    if ~ishandle(source); break; end
    data = guidata(source);
    if ~data.active; break; end

    % De parameters die je actief kan veranderen worden aangepast in elke loop
    data = update_parameters(data);
    % Vervolgens wordt ca_step gecalled.
    [data.T, data.ux, data.uy, data.C] = ca_step(data.T, data.ux, data.uy, data.C, data.params, data.dt);

    % Voegt een generatie toe
    data.generation = data.generation + 1;
    update_ui(data, true);
    guidata(source, data);
    drawnow();
    % Geeft aan hoe snel de simulatie loopt.
    % Kleinere pauze = snellere generatie
    pause(data.speed);
  end
end

% Hier worden alle data punten in het begin geïnitialiseerd.
function data = init_sim(data)
  Td   = data.params.Td;
  T_bg = data.T_bg;
  data.T = T_bg + data.T_base .* (Td + data.params.T_buffer - T_bg);
  data.C = (data.T >= (Td - data.params.delta)) & (data.T <= (Td + data.params.delta));
  data.generation = 0;
  wang    = data.wind_angle * pi / 180;
  data.ux = zeros(data.N, data.N) + (data.wind_speed * cos(wang));
  data.uy = zeros(data.N, data.N) + (data.wind_speed * sin(wang));
end

% Deze functie wordt gecalled zodra een slider wordt veranderd.
% De values worden dan aan alle parameters gelijk gesteld.
function data = update_parameters(data)
  data.dt         = get(data.sl(1), 'value');
  data.T_bg       = get(data.sl(2), 'value');
  data.params.Td  = get(data.sl(3), 'value');
  data.params.q   = get(data.sl(4), 'value');
  data.wind_speed = get(data.sl(5), 'value');
  data.wind_angle = get(data.sl(6), 'value');
  wind_angal    = data.wind_angle * pi / 180;
  data.ux = zeros(data.N, data.N) + (data.wind_speed * cos(wind_angal));
  data.uy = zeros(data.N, data.N) + (data.wind_speed * sin(wind_angal));
end

% Deze functie wordt constant gecalled zodra het menu moet worden geupdate
% Ook wordt hij gecalled als je de view switched, clouds of thermal.
function update_ui(data, runtime)
  if strcmp(data.view_mode, 'cloud')
    set(data.img, 'cdata', data.C);
    colormap(data.axs, [0 0 0; 1 1 1]);
    caxis(data.axs, [0, 1]);
  else
    set(data.img, 'cdata', data.T);
    colormap(data.axs, jet(256));
    caxis(data.axs, [data.T_bg, data.params.Td + data.params.T_buffer]);
  end
  if runtime
    set(data.gen_lbl,  'string', sprintf('Generation: %d', data.generation));
    set(data.wind_lbl, 'string', sprintf('Wind: %.0f deg | %.1f m/s', data.wind_angle, data.wind_speed));
  else
    set(data.gen_lbl,  'string', 'Generation: 0');
    set(data.wind_lbl, 'string', 'Wind: -- deg');
  end
end

% De functie dummy die de focus afneemt van andere knoppen
% Zodat spatie niet andere knoppen indrukt zodra je het klikt.
function clear_focus(source)
  d = guidata(source);
  uicontrol(d.focus_dummy);
end

% Functie die geroepen wordt als je de restart button klikt,
% Reset de wereld naar de begin situatie.
function click_restart(source, event)
  clear_focus(source);
  data = guidata(source);
  data = safely_stop_sim(source, data);
  data = update_parameters(data);
  data = init_sim(data);
  update_ui(data, false);
  guidata(source, data);
end

% Als je hierop klikt worden er random 'wolken' gemaakt.
% Dat gebeurt met imresize en een rand tussen 10 en 15.
function click_random(source, event)
  clear_focus(source);
  data = guidata(source);
  data = safely_stop_sim(source, data);
  data.T_base = custom_resize(rand(10, 15), data.N);
  data = update_parameters(data);
  data = init_sim(data);
  update_ui(data, false);
  guidata(source, data);
end

% Load functie die zorgt dat je files kan inladen.
function click_load(source, event)
  clear_focus(source);
  data = guidata(source);
  data = safely_stop_sim(source, data);
  [filename, filepath] = uigetfile({'*.png;*.jpg;*.bmp', 'Image files'}, 'Select satellite image');
  if ischar(filename)
    im = imread(strcat(filepath, filename));
    data.T_base = custom_resize(double(rgb2gray(im)) / 255, [data.N data.N]);
    data = init_sim(data);
    update_ui(data, false);
  end
  guidata(source, data);
end

% Save functie die zorgt dat je files kan opslaaan.
function click_save(source, event)
  clear_focus(source);
  data = guidata(source);
  [filename, filepath] = uiputfile({'*.png;*.bmp', 'Image file'; '*.csv;*.txt', 'Data file'}, 'Save simulation state');
  if ischar(filename)
    full_path = strcat(filepath, filename);
    if endsWith(filename, '.csv') || endsWith(filename, '.txt')
      csvwrite(full_path, data.T);
    elseif endsWith(filename, '.png') || endsWith(filename, '.bmp')
      cmap = jet(256);
      T_norm = (data.T - data.T_bg) / (data.params.Td + data.params.T_buffer - data.T_bg);
      T_norm = max(min(T_norm, 1.0), 0.0);
      imwrite(uint8(T_norm * 255), cmap, full_path);
    end
  end
  guidata(source, data);
end

% Deze functie zorgt er alleen voor dat de parameter
% view_mode wordt veranderd als de switch button wordt geklikt.
function click_switch(source, event)
  clear_focus(source);
  data = guidata(source);
  if strcmp(data.view_mode, 'cloud')
    data.view_mode = 'thermal';
  else
    data.view_mode = 'cloud';
  end
  update_ui(data, data.active);
  guidata(source, data);
end

% Knop naar de wiki toe
function click_help(source, event)
  web("http://langers.nl/wiki/doku.php?id=cloud_generation_2026:welkom")
end

% Verandert de generatie snelheid wanneer
% De slider knop wordt aangepast.
function speed_changed(source, event)
  clear_focus(source);
  data = guidata(source);
  spd = get(source, 'value');
  data.speed = 1 ./ spd;
  set(data.speed_lbl, 'string', sprintf('Speed: %d g/s', round(spd)));
  guidata(source, data);
end

% Wordt aangeroepen als een ui element geselecteerd is die
% Een toetsen callback maakt naar deze functie zodra er een toets
% Wordt ingedrukt.
function handle_key_input(source, event)
  data = guidata(source);
  switch event.Key
    % Stopt of speelt de simulatie met spatie
    case 'space'
      play_sim(source, event);
    % open help
    case 'slash' % ? = /
      click_help(source, event);
    % restart de simulatie met r
    case 'r'
      click_restart(source, event);
    % Sluit de applicatie af met escape maar zorgt er eerst voor dat de simulatie wordt stop gezet.
    case 'escape'
      if data.active
        data.active = false;
        set(data.play_btn, 'fontsize', 80, 'string', '▶', 'backgroundcolor', [0.0 0.7 0.0]);
        guidata(source, data);
      else
        close(data.fig)
      end
    % Verhoogt de simulatie snelheid als je w in klikt.
    % Heeft een max waarde zodat het de slider niet overschreidt
    case 'w'
      v = min(get(data.speed_sl,'value')+1, get(data.speed_sl,'max'));
      set(data.speed_sl, 'value', v);
      data.speed = 1./v;
      set(data.speed_lbl, 'string', sprintf('Speed: %d g/s', round(v)));
      guidata(source, data);
    % Verlaagt de simulatie snelheid als je s in klikt.
    % Heeft een min waarde zodat het de slider niet overschreidt
    case 's'
      v = max(get(data.speed_sl,'value')-1, get(data.speed_sl,'min'));
      set(data.speed_sl, 'value', v);
      data.speed = 1./v;
      set(data.speed_lbl, 'string', sprintf('Speed: %d g/s', round(v)));
      guidata(source, data);
  end
end

% Stopt de generatie zonder enige crashes
function data = safely_stop_sim(source, data)
  if data.active
    data.active = false;
    set(data.play_btn, 'fontsize', 80, 'string', '▶', 'backgroundcolor', [0.0 0.7 0.0]);
    guidata(source, data);
  end
end

% Zelfgemaakte imresize.
% Wilde niet image package gebruiken, dus moest het zo, gebruikt linspace en interp2
% We zorgen ervoor dat new_N altijd als een enkel getal (scalar) wordt behandeld.
function out = custom_resize(in, new_N)
  % Als new_N een vector is (zoals [250 250]), pakken we alleen het eerste getal.
  if ~isscalar(new_N)
      target_size = new_N(1);
  else
      target_size = new_N;
  end

  [h, w] = size(in);
  [X, Y] = meshgrid(1:w, 1:h);
  [Xq, Yq] = meshgrid(linspace(1, w, target_size), linspace(1, h, target_size));
  out = interp2(X, Y, in, Xq, Yq, 'linear');
end
