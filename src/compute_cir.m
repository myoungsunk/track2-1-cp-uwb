function [cir_mag, t_axis_s, d_axis_m] = compute_cir(S21_vec, cfg)
% COMPUTE_CIR Converts one-tag frequency S21 vector to CIR via windowed IFFT.
%
% INPUT
%   S21_vec  : [N_freq x 1] complex  complex S21 samples
%   cfg      : struct                from setup_config()
%
% OUTPUT
%   cir_mag  : [N_fft x 1]  double   CIR magnitude (linear)
%   t_axis_s : [N_fft x 1]  double   time axis [s]
%   d_axis_m : [N_fft x 1]  double   range axis [m]

S21_vec = S21_vec(:);
if numel(S21_vec) ~= cfg.N_freq
    error('compute_cir: expected %d frequency samples, got %d.', cfg.N_freq, numel(S21_vec));
end
if cfg.N_fft < cfg.N_freq
    error('compute_cir: cfg.N_fft (%d) must be >= cfg.N_freq (%d).', cfg.N_fft, cfg.N_freq);
end

w = local_window(cfg.window_type, cfg.N_freq);
H_win = S21_vec .* w;
H_pad = [H_win; zeros(cfg.N_fft - cfg.N_freq, 1)];

h = ifft(H_pad, cfg.N_fft);
cir_mag = abs(h);

t_axis_s = (0:cfg.N_fft-1).' / (cfg.N_fft * cfg.delta_f);
d_axis_m = cfg.c * t_axis_s;
end

function w = local_window(window_type, n)
% LOCAL_WINDOW Returns a deterministic window without toolbox dependency.
n_idx = (0:n-1).';

switch lower(string(window_type))
    case {"hann", "hanning"}
        if n == 1
            w = 1;
        else
            w = 0.5 * (1 - cos(2 * pi * n_idx / (n - 1)));
        end
    case "hamming"
        if n == 1
            w = 1;
        else
            w = 0.54 - 0.46 * cos(2 * pi * n_idx / (n - 1));
        end
    case {"rect", "rectangular"}
        w = ones(n, 1);
    otherwise
        error('compute_cir: unsupported window_type "%s".', window_type);
end
end

