// 渋分の茶筅モデルを作り、真上から見た画像と横から見た画像(フラットな単色)に書き出す。
// 実行: Unity -batchmode -projectPath <このプロジェクト> -executeMethod ChasenBuilder.Build -quit
using System.Collections.Generic;
using System.IO;
using UnityEngine;

public static class ChasenBuilder
{
    static readonly Color Bamboo = new Color(0.88f, 0.76f, 0.54f);
    static readonly Color BambooDark = new Color(0.76f, 0.62f, 0.40f);
    static readonly Color Thread = new Color(0.12f, 0.10f, 0.09f);

    public static void Build()
    {
        var root = new GameObject("Chasen");
        // 持ち手(竹の筒)と節
        var handle = Cylinder(0.13f, 0f, 0.9f); Add(root, handle, Bamboo);
        Add(root, Cylinder(0.135f, 0.55f, 0.58f), BambooDark);
        // 糸
        var thread = Cylinder(0.145f, 0.9f, 0.96f); Add(root, thread, Thread);
        // 外側の穂: 外へ広がり、先は内へ巻く
        var outer = new List<Vector3[]>();
        for (int i = 0; i < 72; i++)
        {
            float a = 2 * Mathf.PI * i / 72;
            var d = new Vector3(Mathf.Cos(a), 0, Mathf.Sin(a));
            outer.Add(new[] { d * 0.13f + Vector3.up * 0.96f, d * 0.30f + Vector3.up * 1.40f, d * 0.44f + Vector3.up * 1.85f, d * 0.40f + Vector3.up * 2.02f, d * 0.33f + Vector3.up * 2.05f });
        }
        var outerMesh = Tines(outer, 0.012f); Add(root, outerMesh, Bamboo);
        // 内側の穂: 中心で束ねる
        var inner = new List<Vector3[]>();
        for (int i = 0; i < 36; i++)
        {
            float a = 2 * Mathf.PI * i / 36;
            var d = new Vector3(Mathf.Cos(a), 0, Mathf.Sin(a));
            inner.Add(new[] { d * 0.10f + Vector3.up * 0.96f, d * 0.12f + Vector3.up * 1.50f, d * 0.04f + Vector3.up * 2.02f });
        }
        var innerMesh = Tines(inner, 0.014f); Add(root, innerMesh, BambooDark);

        var outDir = Path.Combine(Application.dataPath, "../Export");
        Directory.CreateDirectory(outDir);
        // アプリ(SceneKit)で動かすための 3D モデル。部品ごとに書き出し、色はアプリ側でつける
        File.WriteAllText(Path.Combine(outDir, "chasen_handle.obj"), ChawanBuilder.ToObj(handle));
        File.WriteAllText(Path.Combine(outDir, "chasen_thread.obj"), ChawanBuilder.ToObj(thread));
        File.WriteAllText(Path.Combine(outDir, "chasen_tines_outer.obj"), ChawanBuilder.ToObj(outerMesh));
        File.WriteAllText(Path.Combine(outDir, "chasen_tines_inner.obj"), ChawanBuilder.ToObj(innerMesh));
        // 真上から(穂を下にして茶碗に入れたところを、上から見る = 持ち手の端と、その周りに広がる穂)
        root.transform.rotation = Quaternion.Euler(180, 0, 0);
        Render(Path.Combine(outDir, "chasen_top.png"), new Vector3(0, 5, 0), Quaternion.Euler(90, 0, 0), 0.5f, Vector3.zero);
        // 横から(立てて置いたところ)
        root.transform.rotation = Quaternion.identity;
        Render(Path.Combine(outDir, "chasen_side.png"), new Vector3(0, 1.05f, -5), Quaternion.identity, 1.1f, Vector3.zero);
        Debug.Log("ChasenBuilder: exported to " + outDir);
    }

    static void Add(GameObject root, Mesh mesh, Color color)
    {
        var go = new GameObject("Part");
        go.transform.SetParent(root.transform, false);
        go.AddComponent<MeshFilter>().sharedMesh = mesh;
        var mat = new Material(Shader.Find("Unlit/Color")) { color = color };
        go.AddComponent<MeshRenderer>().sharedMaterial = mat;
    }

    static Mesh Cylinder(float r, float y0, float y1, int seg = 48)
    {
        var v = new List<Vector3>(); var t = new List<int>();
        for (int i = 0; i <= seg; i++)
        {
            float a = 2 * Mathf.PI * i / seg;
            v.Add(new Vector3(Mathf.Cos(a) * r, y0, Mathf.Sin(a) * r));
            v.Add(new Vector3(Mathf.Cos(a) * r, y1, Mathf.Sin(a) * r));
        }
        for (int i = 0; i < seg; i++) { int a = i * 2; t.AddRange(new[] { a, a + 1, a + 2, a + 1, a + 3, a + 2, a, a + 2, a + 1, a + 1, a + 2, a + 3 }); }
        // ふた
        int c0 = v.Count; v.Add(new Vector3(0, y0, 0)); int c1 = v.Count; v.Add(new Vector3(0, y1, 0));
        for (int i = 0; i < seg; i++) { t.AddRange(new[] { c0, i * 2, i * 2 + 2, c0, i * 2 + 2, i * 2, c1, i * 2 + 1, i * 2 + 3, c1, i * 2 + 3, i * 2 + 1 }); }
        var m = new Mesh(); m.SetVertices(v); m.SetTriangles(t, 0); return m;
    }

    // 穂: 折れ線に沿った細い帯(両面)
    static Mesh Tines(List<Vector3[]> lines, float w)
    {
        var v = new List<Vector3>(); var t = new List<int>();
        foreach (var line in lines)
        {
            var side = Vector3.Cross((line[line.Length - 1] - line[0]).normalized, Vector3.up).normalized * w;
            if (side == Vector3.zero) side = Vector3.right * w;
            int start = v.Count;
            foreach (var p in line) { v.Add(p - side); v.Add(p + side); }
            for (int i = 0; i < line.Length - 1; i++)
            {
                int a = start + i * 2;
                t.AddRange(new[] { a, a + 1, a + 2, a + 1, a + 3, a + 2, a, a + 2, a + 1, a + 1, a + 2, a + 3 });
            }
        }
        var m = new Mesh { indexFormat = UnityEngine.Rendering.IndexFormat.UInt32 }; m.SetVertices(v); m.SetTriangles(t, 0); return m;
    }

    static void Render(string path, Vector3 pos, Quaternion rot, float size, Vector3 _)
    {
        var camGo = new GameObject("Camera");
        var cam = camGo.AddComponent<Camera>();
        cam.orthographic = true;
        cam.orthographicSize = size;
        cam.transform.SetPositionAndRotation(pos, rot);
        cam.clearFlags = CameraClearFlags.SolidColor;
        cam.backgroundColor = new Color(0, 0, 0, 0);
        const int px = 768;
        var rt = new RenderTexture(px, px, 24, RenderTextureFormat.ARGB32) { antiAliasing = 8 };
        cam.targetTexture = rt;
        cam.Render();
        RenderTexture.active = rt;
        var tex = new Texture2D(px, px, TextureFormat.RGBA32, false);
        tex.ReadPixels(new Rect(0, 0, px, px), 0, 0);
        tex.Apply();
        File.WriteAllBytes(path, tex.EncodeToPNG());
        RenderTexture.active = null;
        cam.targetTexture = null;
        Object.DestroyImmediate(camGo);
    }
}
