// 結果画面の「抹茶の缶」を作り、斜め上から見た画像(透明背景)に書き出す。
// 本物らしく見せるため、この絵だけは光と陰影をつける(開発者の依頼)。
// 実行: Unity -batchmode -projectPath <このプロジェクト> -executeMethod TeaCanBuilder.Build -quit
using System.IO;
using UnityEngine;

public static class TeaCanBuilder
{
    public static void Build()
    {
        var root = new GameObject("TeaCan");
        var shader = Shader.Find("Standard");
        Material Mat(Color c, float metal, float smooth)
        {
            var m = new Material(shader) { color = c };
            m.SetFloat("_Metallic", metal);
            m.SetFloat("_Glossiness", smooth);
            return m;
        }
        var green = Mat(new Color(0.16f, 0.30f, 0.14f), 0.35f, 0.72f);      // 抹茶色の塗りの缶
        var gold = Mat(new Color(0.78f, 0.62f, 0.32f), 0.9f, 0.65f);        // ふちの金色
        var washi = Mat(new Color(0.93f, 0.90f, 0.82f), 0.0f, 0.15f);       // 和紙のラベル
        var ink = Mat(new Color(0.12f, 0.10f, 0.08f), 0.0f, 0.2f);          // ラベルの文字の代わりの墨の帯
        var red = Mat(new Color(0.72f, 0.22f, 0.16f), 0.0f, 0.3f);          // 朱の印

        Part(root, PrimitiveType.Cylinder, green, new Vector3(0, 0.9f, 0), new Vector3(1.4f, 0.9f, 1.4f));      // 胴
        Part(root, PrimitiveType.Cylinder, green, new Vector3(0, 2.0f, 0), new Vector3(1.46f, 0.22f, 1.46f));   // ふた
        Part(root, PrimitiveType.Cylinder, gold, new Vector3(0, 1.80f, 0), new Vector3(1.47f, 0.025f, 1.47f));  // ふたの下の金の線
        Part(root, PrimitiveType.Cylinder, gold, new Vector3(0, 2.225f, 0), new Vector3(1.40f, 0.012f, 1.40f)); // ふたの上の金の線
        Part(root, PrimitiveType.Cylinder, gold, new Vector3(0, 0.04f, 0), new Vector3(1.42f, 0.03f, 1.42f));   // 底の金の線
        // 和紙のラベル(胴の前面に巻いた帯)
        var label = Part(root, PrimitiveType.Cylinder, washi, new Vector3(0, 0.95f, 0), new Vector3(1.415f, 0.48f, 1.415f));
        // ラベルの「抹茶」(ヒラギノ明朝で書いた絵 tea_label.png を、ラベルの前に貼る)
        var labelTex = new Texture2D(2, 2);
        labelTex.LoadImage(File.ReadAllBytes(Path.Combine(Application.dataPath, "../Export/tea_label.png")));
        var textMat = new Material(Shader.Find("Unlit/Transparent")) { mainTexture = labelTex };
        var quad = Part(root, PrimitiveType.Quad, textMat, new Vector3(0, 0.95f, -0.712f), new Vector3(0.42f, 0.84f, 1f));
        root.transform.rotation = Quaternion.Euler(0, 18, 0);

        var key = new GameObject("Key").AddComponent<Light>();
        key.type = LightType.Directional; key.intensity = 1.1f; key.color = new Color(1f, 0.97f, 0.92f);
        key.transform.rotation = Quaternion.Euler(38, -40, 0);
        key.shadows = LightShadows.Soft;
        var fill = new GameObject("Fill").AddComponent<Light>();
        fill.type = LightType.Directional; fill.intensity = 0.35f; fill.transform.rotation = Quaternion.Euler(20, 140, 0);
        RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Trilight;
        RenderSettings.ambientSkyColor = new Color(0.55f, 0.55f, 0.55f);
        RenderSettings.ambientEquatorColor = new Color(0.4f, 0.4f, 0.38f);
        RenderSettings.ambientGroundColor = new Color(0.25f, 0.24f, 0.22f);

        var cam = new GameObject("Camera").AddComponent<Camera>();
        cam.fieldOfView = 22;
        cam.transform.position = new Vector3(0, 3.6f, -6.6f);
        cam.transform.LookAt(new Vector3(0, 1.05f, 0));
        cam.clearFlags = CameraClearFlags.SolidColor;
        cam.backgroundColor = new Color(0, 0, 0, 0);

        const int px = 1024;
        var rt = new RenderTexture(px, px, 24, RenderTextureFormat.ARGB32) { antiAliasing = 8 };
        cam.targetTexture = rt; cam.Render(); RenderTexture.active = rt;
        var tex = new Texture2D(px, px, TextureFormat.RGBA32, false);
        tex.ReadPixels(new Rect(0, 0, px, px), 0, 0); tex.Apply();
        var outDir = Path.Combine(Application.dataPath, "../Export");
        Directory.CreateDirectory(outDir);
        File.WriteAllBytes(Path.Combine(outDir, "tea_can.png"), tex.EncodeToPNG());
        RenderTexture.active = null; cam.targetTexture = null;
        Debug.Log("TeaCanBuilder: exported");
    }

    static GameObject Part(GameObject root, PrimitiveType t, Material m, Vector3 pos, Vector3 scale)
    {
        var g = GameObject.CreatePrimitive(t);
        g.transform.SetParent(root.transform, false);
        g.transform.localPosition = pos; g.transform.localScale = scale;
        g.GetComponent<Renderer>().sharedMaterial = m;
        return g;
    }
}
