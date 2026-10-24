// 渋分の茶碗モデルを作り、真上から見た画像(フラットな単色)と OBJ に書き出す。
// 実行: Unity -batchmode -projectPath <このプロジェクト> -executeMethod ChawanBuilder.Build -quit
using System.Collections.Generic;
using System.IO;
using System.Text;
using UnityEngine;

public static class ChawanBuilder
{
    // 寸法(茶碗の外径を 1 とした比)。アプリ側の水面の大きさもこの値で合わせる
    const float OuterRadius = 1.0f;
    const float RimInner = 0.88f;   // 口縁の内側
    const float Liquid = 0.80f;     // 抹茶の水面の半径(真上から見えるところ)
    const int Segments = 160;

    static readonly Color Kogecha = new Color(0.17f, 0.12f, 0.09f);

    // 茶碗の種類: 名前, 地の色, 斑点の色, 斑点の量(0〜1)
    static readonly (string id, Color body, Color speck, float amount)[] Styles =
    {
        ("shino", new Color(0.91f, 0.87f, 0.80f), new Color(0.72f, 0.50f, 0.36f), 0.55f),   // 志野(アイコンの茶碗)
        ("kuroraku", Kogecha, new Color(0.26f, 0.20f, 0.16f), 0.25f),                           // 黒楽
        ("oribe", new Color(0.24f, 0.36f, 0.24f), new Color(0.18f, 0.28f, 0.18f), 0.35f),     // 織部
        ("nezumi", new Color(0.55f, 0.53f, 0.51f), new Color(0.86f, 0.84f, 0.80f), 0.45f),    // 鼠志野
    };

    public static void Build()
    {
        foreach (var style in Styles) BuildOne(style.id, style.body, style.speck, style.amount);
    }

    static void BuildOne(string id, Color body, Color speck, float amount)
    {
        var root = new GameObject("Chawan");
        var bowl = new GameObject("Bowl");
        bowl.transform.SetParent(root.transform);
        var mesh = Lathe(Profile());
        bowl.AddComponent<MeshFilter>().sharedMesh = mesh;
        // フラットデザイン: 陰影をつけない単色(Unlit)。手づくりの茶碗らしい、わずかにゆらいだ輪郭だけを残す
        var shader = Shader.Find("Unlit/Texture") ?? Shader.Find("Universal Render Pipeline/Unlit");
        var mat = new Material(shader) { mainTexture = SpeckleTexture(body, speck, amount, id.GetHashCode()) };
        bowl.AddComponent<MeshRenderer>().sharedMaterial = mat;

        // 光: 少し斜め上から。縁にやわらかいハイライトが出るようにする
        var lightGo = new GameObject("Light");
        var light = lightGo.AddComponent<Light>();
        light.type = LightType.Directional;
        light.intensity = 1.15f;
        light.color = new Color(1f, 0.97f, 0.92f);
        lightGo.transform.rotation = Quaternion.Euler(62, -35, 0);
        RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Flat;
        RenderSettings.ambientLight = new Color(0.36f, 0.34f, 0.32f);

        // カメラ: 真上から(机に置いた iPhone の視点)、平行投影
        var camGo = new GameObject("Camera");
        var cam = camGo.AddComponent<Camera>();
        cam.orthographic = true;
        cam.orthographicSize = OuterRadius * 1.02f;
        cam.transform.position = new Vector3(0, 5, 0);
        cam.transform.rotation = Quaternion.Euler(90, 0, 0);
        cam.clearFlags = CameraClearFlags.SolidColor;
        cam.backgroundColor = new Color(0, 0, 0, 0);

        var outDir = Path.Combine(Application.dataPath, "../Export");
        Directory.CreateDirectory(outDir);
        RenderPng(cam, Path.Combine(outDir, $"chawan_{id}.png"), 1536);
        File.WriteAllText(Path.Combine(outDir, "chawan.obj"), ToObj(mesh));
        Object.DestroyImmediate(root); Object.DestroyImmediate(lightGo); Object.DestroyImmediate(camGo);
        File.WriteAllText(Path.Combine(outDir, "chawan.json"),
            $"{{\"outerRadius\":{OuterRadius},\"rimInner\":{RimInner},\"liquid\":{Liquid},\"imageExtent\":{OuterRadius * 1.02f}}}");
        Debug.Log("ChawanBuilder: exported to " + outDir);
    }

    // 断面(半径, 高さ)。高台 → 胴 → 口縁 → 内側の壁 → 見込み(底)。少し揺らして手づくりの楽茶碗らしくする
    static List<Vector2> Profile()
    {
        var p = new List<Vector2>
        {
            new Vector2(0.00f, 0.00f), new Vector2(0.42f, 0.00f), new Vector2(0.44f, 0.08f), new Vector2(0.52f, 0.10f),
            new Vector2(0.80f, 0.22f), new Vector2(0.95f, 0.45f), new Vector2(1.00f, 0.70f), new Vector2(0.99f, 0.80f),
            new Vector2(0.94f, 0.84f), new Vector2(RimInner, 0.80f), new Vector2(0.85f, 0.60f), new Vector2(Liquid, 0.52f),
            new Vector2(0.60f, 0.30f), new Vector2(0.30f, 0.20f), new Vector2(0.00f, 0.18f),
        };
        return p;
    }

    static Mesh Lathe(List<Vector2> profile)
    {
        var verts = new List<Vector3>();
        var tris = new List<int>();
        var rng = new System.Random(7);
        var wobble = new float[Segments + 1];
        for (int s = 0; s <= Segments; s++) wobble[s] = 1f + 0.006f * Mathf.Sin(s * 0.11f) + 0.003f * (float)(rng.NextDouble() - 0.5);
        wobble[Segments] = wobble[0];
        for (int s = 0; s <= Segments; s++)
        {
            float a = 2 * Mathf.PI * s / Segments;
            foreach (var pt in profile)
                verts.Add(new Vector3(Mathf.Cos(a) * pt.x * wobble[s], pt.y, Mathf.Sin(a) * pt.x * wobble[s]));
        }
        int n = profile.Count;
        for (int s = 0; s < Segments; s++)
            for (int i = 0; i < n - 1; i++)
            {
                int a = s * n + i, b = (s + 1) * n + i;
                tris.AddRange(new[] { a, a + 1, b, a + 1, b + 1, b });
            }
        var mesh = new Mesh { indexFormat = UnityEngine.Rendering.IndexFormat.UInt32 };
        mesh.SetVertices(verts);
        var uvs = new List<Vector2>();
        foreach (var v in verts) uvs.Add(new Vector2(v.x * 0.5f + 0.5f, v.z * 0.5f + 0.5f));
        mesh.SetUVs(0, uvs);
        mesh.SetTriangles(tris, 0);
        mesh.RecalculateNormals();
        return mesh;
    }

    // 地の色に、小さな斑点を散らした模様(フラット: 陰影はつけない)
    static Texture2D SpeckleTexture(Color body, Color speck, float amount, int seed)
    {
        const int size = 1024;
        var tex = new Texture2D(size, size, TextureFormat.RGBA32, false);
        var px = new Color[size * size];
        for (int i = 0; i < px.Length; i++) px[i] = body;
        var rng = new System.Random(seed);
        int count = (int)(9000 * amount);
        for (int n = 0; n < count; n++)
        {
            int cx = rng.Next(size), cy = rng.Next(size);
            int r = rng.NextDouble() < 0.9 ? 1 : 2;
            for (int y = -r; y <= r; y++)
                for (int x = -r; x <= r; x++)
                {
                    int xx = cx + x, yy = cy + y;
                    if (xx < 0 || yy < 0 || xx >= size || yy >= size || x * x + y * y > r * r) continue;
                    px[yy * size + xx] = speck;
                }
        }
        tex.SetPixels(px);
        tex.Apply();
        return tex;
    }

    static void RenderPng(Camera cam, string path, int size)
    {
        var rt = new RenderTexture(size, size, 24, RenderTextureFormat.ARGB32) { antiAliasing = 8 };
        cam.targetTexture = rt;
        cam.Render();
        RenderTexture.active = rt;
        var tex = new Texture2D(size, size, TextureFormat.RGBA32, false);
        tex.ReadPixels(new Rect(0, 0, size, size), 0, 0);
        tex.Apply();
        File.WriteAllBytes(path, tex.EncodeToPNG());
        RenderTexture.active = null;
        cam.targetTexture = null;
    }

    internal static string ToObj(Mesh mesh)
    {
        var sb = new StringBuilder("# 渋分 茶碗 (Unity ChawanBuilder)\no Chawan\n");
        foreach (var v in mesh.vertices) sb.AppendFormat(System.Globalization.CultureInfo.InvariantCulture, "v {0} {1} {2}\n", -v.x, v.y, v.z);
        foreach (var n in mesh.normals) sb.AppendFormat(System.Globalization.CultureInfo.InvariantCulture, "vn {0} {1} {2}\n", -n.x, n.y, n.z);
        var t = mesh.triangles;
        for (int i = 0; i < t.Length; i += 3)
            sb.AppendFormat("f {0}//{0} {2}//{2} {1}//{1}\n", t[i] + 1, t[i + 1] + 1, t[i + 2] + 1);
        return sb.ToString();
    }
}
