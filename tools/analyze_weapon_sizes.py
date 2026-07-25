"""分析近战武器 GLB 模型的原始尺寸（从 glTF accessor min/max 提取 POSITION 包围盒）"""
import struct, json, os, sys

def parse_glb(path):
    """解析 GLB 文件，返回 glTF JSON 和 bin buffer"""
    with open(path, 'rb') as f:
        magic, version, length = struct.unpack('<III', f.read(12))
        if magic != 0x46546C67:
            return None
        # 读取 chunks
        json_data = None
        while f.tell() < length:
            chunk_header = f.read(8)
            if len(chunk_header) < 8:
                break
            chunk_len, chunk_type = struct.unpack('<II', chunk_header)
            chunk_data = f.read(chunk_len)
            if chunk_type == 0x4E4F534A:  # JSON
                json_data = json.loads(chunk_data.decode('utf-8'))
        return json_data

def get_mesh_aabb(gltf):
    """从 glTF JSON 提取所有 mesh primitive 的 POSITION accessor 合并包围盒"""
    accessors = gltf.get('accessors', [])
    meshes = gltf.get('meshes', [])
    
    min_bound = None
    max_bound = None
    
    for mesh in meshes:
        for prim in mesh.get('primitives', []):
            pos_idx = prim.get('attributes', {}).get('POSITION')
            if pos_idx is None:
                continue
            acc = accessors[pos_idx]
            acc_min = acc.get('min')
            acc_max = acc.get('max')
            if acc_min and acc_max:
                if min_bound is None:
                    min_bound = list(acc_min)
                    max_bound = list(acc_max)
                else:
                    for i in range(3):
                        min_bound[i] = min(min_bound[i], acc_min[i])
                        max_bound[i] = max(max_bound[i], acc_max[i])
    
    if min_bound is None:
        return None
    
    size = [max_bound[i] - min_bound[i] for i in range(3)]
    return {'min': min_bound, 'max': max_bound, 'size': size}

def main():
    weapon_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 
                              'models', 'melee_weapons')
    
    results = []
    for fname in sorted(os.listdir(weapon_dir)):
        if not fname.lower().endswith('.glb'):
            continue
        path = os.path.join(weapon_dir, fname)
        gltf = parse_glb(path)
        if gltf is None:
            print(f"[WARN] 无法解析: {fname}")
            continue
        aabb = get_mesh_aabb(gltf)
        if aabb is None:
            print(f"[WARN] 无 POSITION 数据: {fname}")
            continue
        sx, sy, sz = aabb['size']
        max_axis = max(sx, sy, sz)
        results.append({
            'name': fname,
            'sx': sx, 'sy': sy, 'sz': sz,
            'max_axis': max_axis,
        })
    
    # 按最大轴降序排列
    results.sort(key=lambda r: r['max_axis'], reverse=True)
    
    print("\n===== 近战武器模型尺寸分析 =====")
    print("（单位：GLB 原始坐标，按最大轴降序）\n")
    print(f"{'模型文件':<28} {'X(宽)':>10} {'Y(高)':>10} {'Z(深)':>10} {'最大轴':>10}")
    print("-" * 72)
    for r in results:
        print(f"{r['name']:<28} {r['sx']:>10.4f} {r['sy']:>10.4f} {r['sz']:>10.4f} {r['max_axis']:>10.4f}")
    print("-" * 72)
    print(f"共 {len(results)} 个模型")
    
    # 缩放建议
    print("\n===== 缩放建议（目标世界尺寸 ≈ 0.7m）=====")
    print("怪物：父级 CharacterModel scale=0.5")
    print("玩家：viewmodel 无父级缩放\n")
    print(f"{'模型文件':<28} {'怪物缩放':>12} {'玩家viewmodel':>14}")
    print("-" * 58)
    for r in results:
        if r['max_axis'] < 0.0001:
            continue
        monster_scale = 0.7 / (0.5 * r['max_axis'])
        player_scale = 0.7 / r['max_axis']
        print(f"{r['name']:<28} {monster_scale:>12.4f} {player_scale:>14.4f}")
    
    # 当前使用配置对比
    print("\n===== 当前配置验证 =====")
    for r in results:
        if r['name'] == 'Mistsplitter.glb':
            actual = r['max_axis'] * 0.3
            print(f"玩家 Mistsplitter.glb × 0.3 → 视觉尺寸 ≈ {actual:.4f}m")
        if r['name'] == 'Sword6.glb':
            actual = r['max_axis'] * 1.5 * 0.5
            print(f"怪物 Sword6.glb × 1.5 (×0.5父级) → 世界尺寸 ≈ {actual:.4f}m")

if __name__ == '__main__':
    main()
