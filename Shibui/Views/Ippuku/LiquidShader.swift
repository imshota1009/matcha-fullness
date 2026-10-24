import Foundation

/// 抹茶の液面を GPU で描くシェーダー(SceneKit のシェーダーモディファイア。中身は Metal)。
/// CPU から受け取るのは 96×96 のテクスチャ simTex だけ: r = 泡の量、g = 泡の大きさ(1=粗い〜0=きめ細かい)、b = 液面の高さ。
/// 1画素ずつ、次を計算する(SPEC 5章「泡と波の表現」C・D):
/// - 色: 泡が多いほど、濃く暗い緑 → 淡く明るい抹茶色
/// - 泡: 画面を泡の大きさに合わせたマス目に区切り、マスごとの乱数で泡の位置と出るかどうかを決める(手続き的な泡)。
///   泡の段階(粗い/中/細かい/きめ細かい)の半径は TemaeConstants と同じ。となりの2段階を、混ざり具合に応じて重ねて描くので、
///   段階が変わるときは前の泡と次の泡がフェードしながら入れかわる
/// - 抹茶の粒: きめ細かい泡の中に、濃い緑の小さな点を少しだけ
/// - 明暗: 液面の高さの傾きから、明るさを2〜3段階でうっすら
/// - 縁: 茶碗の内壁との境目に、細く明るい輪
/// どれもグラデーションや光沢は使わず、色の面と丸だけで描く(フラット)。
enum LiquidShader {
    static let surface = """
    float lqHash(float2 p) { return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453); }

    // 段階 s の泡の層。泡の中なら 1、外なら 0(ふちは少しだけなめらかに)
    float lqBubbles(float2 uv, float foam, float radius, float density, float salt) {
        float cell = radius * density;
        float2 g = uv / cell;
        float2 id = floor(g);
        float2 f = fract(g);
        float2 c = float2(0.25, 0.25) + 0.5 * float2(lqHash(id + salt), lqHash(id + salt + 17.3));
        float d = length((f - c) * cell);
        // 泡の量がそのマスのしきい値をこえたら、泡が出る
        float threshold = 0.04 + 0.92 * lqHash(id + salt + 41.7);
        float on = step(threshold, foam);
        return on * (1.0 - smoothstep(radius * 0.82, radius, d));
    }

    #pragma arguments
    texture2d<float> simTex;
    float foamAvg;

    #pragma body
    constexpr sampler sm(filter::linear, address::clamp_to_edge);
    float2 uv = _surface.diffuseTexcoord;
    float4 sim = simTex.sample(sm, uv);
    float foam = sim.r;
    float size = sim.g;

    float3 dark = float3(0.20, 0.33, 0.12);
    float3 light = float3(0.72, 0.79, 0.45);
    float3 col = mix(dark, light, pow(foam, 0.8));

    // 明暗(液面の傾きから、2〜3段階でうっすら)
    float e = 1.0 / 96.0;
    float slope = simTex.sample(sm, uv + float2(e, 0)).b - simTex.sample(sm, uv - float2(e, 0)).b
                + simTex.sample(sm, uv - float2(0, e)).b - simTex.sample(sm, uv + float2(0, e)).b;
    col *= slope > 0.05 ? 1.035 : (slope < -0.05 ? 0.965 : 1.0);

    // 泡: 段階(0=粗い〜3=きめ細かい)を連続値にして、となりの2段階を重ねる
    float radii[4] = { 7.0 / 640.0, 4.5 / 640.0, 2.6 / 640.0, 1.2 / 640.0 };
    float density[4] = { 6.0, 4.6, 3.6, 2.6 };
    float level = (1.0 - size) * 3.0;
    int lower = min(2, int(level));
    float t = level - float(lower);
    for (int k = 0; k < 2; k++) {
        int s = lower + k;
        float w = k == 0 ? (1.0 - t) : t;
        if (w < 0.01) { continue; }
        float b = lqBubbles(uv, foam, radii[s], density[s], float(s) * 13.0);
        float3 bubble = s <= 1 ? min(float3(1.0), col + float3(0.10, 0.10, 0.06)) : light + float3(0.06);
        col = mix(col, bubble, b * w * (s <= 1 ? 0.55 : 0.6));
        // 抹茶の粒(細かい泡の中に、濃い緑の点を少し)
        if (s >= 2) {
            float g2 = lqBubbles(uv + 0.37, foam, 1.0 / 640.0, 14.0, 91.0);
            col = mix(col, float3(0.27, 0.40, 0.15), g2 * w * 0.7);
        }
    }

    // 縁: 茶碗の内壁との境目に、細く明るい輪
    float r = length(uv - 0.5) * 2.0;
    float ring = smoothstep(0.955, 0.975, r) * (1.0 - smoothstep(0.985, 1.0, r));
    col = mix(col, float3(0.86, 0.90, 0.66), ring * (0.3 + 0.6 * foamAvg));

    // SceneKit は「リニア」の色で計算するので、画面で見る色(sRGB)からリニアに直して渡す(直さないと白っぽくなる)
    _surface.diffuse = float4(pow(col, float3(2.2)), 1.0);
    """
}
