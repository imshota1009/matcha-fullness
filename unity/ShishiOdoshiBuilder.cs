// タイマーのししおどし(御茶ノ水駅のししおどしのイメージ)を部品ごとに作り、OBJ に書き出す。
// 竹筒(口は斜めに切る・節つき)、2本の支柱と軸、かけい(水を送る細い竹)、竹筒の中の水。岩などの囲いはなし。
// アプリ(SceneKit)で竹筒を傾け、水が溜まる・落ちる動きをつける。
// 実行: Unity -batchmode -projectPath <このプロジェクト> -executeMethod ShishiOdoshiBuilder.Build -quit
using System.Collections.Generic;
using System.IO;
using UnityEngine;

public static class ShishiOdoshiBuilder
{
    const int Seg = 40;

    public static void Build()
    {
        var outDir = Path.Combine(Application.dataPath, "../Export");
        Directory.CreateDirectory(outDir);
        // 竹筒: x 軸に沿って、しっぽ(x=-0.55)から口(x=+0.95)へ。口は斜めに切る。軸(回転の中心)は原点
        File.WriteAllText(Path.Combine(outDir, "shishi_tube.obj"), ChawanBuilder.ToObj(Tube(0.11f, -0.55f, 0.95f, 0.22f, true)));
        // 節(竹の輪)
        var nodes = new List<Mesh> { Ring(0.118f, -0.18f, 0.03f), Ring(0.118f, 0.42f, 0.03f) };
        File.WriteAllText(Path.Combine(outDir, "shishi_nodes.obj"), ChawanBuilder.ToObj(Combine(nodes)));
        // 竹筒の中の水(口の側に溜まる。アプリで長さを変える)。x=0〜1 の長さ1の筒
        File.WriteAllText(Path.Combine(outDir, "shishi_water.obj"), ChawanBuilder.ToObj(Tube(0.085f, 0f, 1f, 0f, false)));
        // 支柱2本(竹筒の手前と奥)と、軸
        var posts = new List<Mesh>
        {
            Post(new Vector3(0, 0, 0.17f), 0.045f, -0.85f, 0.1f),
            Post(new Vector3(0, 0, -0.17f), 0.045f, -0.85f, 0.1f),
        };
        File.WriteAllText(Path.Combine(outDir, "shishi_posts.obj"), ChawanBuilder.ToObj(Combine(posts)));
        File.WriteAllText(Path.Combine(outDir, "shishi_axle.obj"), ChawanBuilder.ToObj(Axle(0.025f, 0.22f)));
        // かけい: 口の上に、斜め上から伸びる細い竹(先は斜めに切る)
        File.WriteAllText(Path.Combine(outDir, "shishi_kakei.obj"), ChawanBuilder.ToObj(Tube(0.05f, 0f, 0.9f, 0.08f, true)));
        Debug.Log("ShishiOdoshiBuilder: exported");
    }

    /// x 軸に沿った筒。`slant` だけ口(x の大きい側)を斜めに切る。open なら口の面をつくらない
    static Mesh Tube(float r, float x0, float x1, float slant, bool open)
    {
        var v = new List<Vector3>(); var t = new List<int>();
        for (int i = 0; i <= Seg; i++)
        {
            float a = 2 * Mathf.PI * i / Seg;
            float y = Mathf.Cos(a) * r, z = Mathf.Sin(a) * r;
            v.Add(new Vector3(x0, y, z));
            // 口は上側ほど長く(斜めに切る)
            v.Add(new Vector3(x1 + slant * (y / r), y, z));
        }
        for (int i = 0; i < Seg; i++)
        {
            int a = i * 2;
            t.AddRange(new[] { a, a + 2, a + 1, a + 1, a + 2, a + 3 });   // 外側
            t.AddRange(new[] { a, a + 1, a + 2, a + 1, a + 3, a + 2 });   // 内側(口から中が見える)
        }
        // しっぽ側のふた
        int c = v.Count; v.Add(new Vector3(x0, 0, 0));
        for (int i = 0; i < Seg; i++) t.AddRange(new[] { c, i * 2 + 2, i * 2, c, i * 2, i * 2 + 2 });
        if (!open)
        {
            int c1 = v.Count; v.Add(new Vector3(x1, 0, 0));
            for (int i = 0; i < Seg; i++) t.AddRange(new[] { c1, i * 2 + 1, i * 2 + 3, c1, i * 2 + 3, i * 2 + 1 });
        }
        var m = new Mesh(); m.SetVertices(v); m.SetTriangles(t, 0); m.RecalculateNormals(); return m;
    }

    static Mesh Ring(float r, float x, float w) => Tube(r, x - w / 2, x + w / 2, 0, false);

    /// 縦の支柱(y 方向)
    static Mesh Post(Vector3 at, float r, float y0, float y1)
    {
        var v = new List<Vector3>(); var t = new List<int>();
        for (int i = 0; i <= Seg; i++)
        {
            float a = 2 * Mathf.PI * i / Seg;
            v.Add(at + new Vector3(Mathf.Cos(a) * r, y0, Mathf.Sin(a) * r));
            v.Add(at + new Vector3(Mathf.Cos(a) * r, y1, Mathf.Sin(a) * r));
        }
        for (int i = 0; i < Seg; i++) { int a = i * 2; t.AddRange(new[] { a, a + 1, a + 2, a + 1, a + 3, a + 2 }); }
        int top = v.Count; v.Add(at + new Vector3(0, y1, 0));
        for (int i = 0; i < Seg; i++) t.AddRange(new[] { top, i * 2 + 3, i * 2 + 1 });
        var m = new Mesh(); m.SetVertices(v); m.SetTriangles(t, 0); m.RecalculateNormals(); return m;
    }

    /// 軸(z 方向)
    static Mesh Axle(float r, float half)
    {
        var v = new List<Vector3>(); var t = new List<int>();
        for (int i = 0; i <= Seg; i++)
        {
            float a = 2 * Mathf.PI * i / Seg;
            v.Add(new Vector3(Mathf.Cos(a) * r, Mathf.Sin(a) * r, -half));
            v.Add(new Vector3(Mathf.Cos(a) * r, Mathf.Sin(a) * r, half));
        }
        for (int i = 0; i < Seg; i++) { int a = i * 2; t.AddRange(new[] { a, a + 1, a + 2, a + 1, a + 3, a + 2 }); }
        var m = new Mesh(); m.SetVertices(v); m.SetTriangles(t, 0); m.RecalculateNormals(); return m;
    }

    static Mesh Combine(List<Mesh> parts)
    {
        var ci = new CombineInstance[parts.Count];
        for (int i = 0; i < parts.Count; i++) ci[i] = new CombineInstance { mesh = parts[i], transform = Matrix4x4.identity };
        var m = new Mesh { indexFormat = UnityEngine.Rendering.IndexFormat.UInt32 };
        m.CombineMeshes(ci, true, true);
        return m;
    }
}
