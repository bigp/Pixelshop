package pixelshop.g2d {
	import com.genome2d.components.GCamera;
	import com.genome2d.components.GTransform;
	import com.genome2d.components.renderables.GRenderable;
	import com.genome2d.context.GContext;
	import com.genome2d.core.GNode;
	import com.genome2d.textures.GTexture;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	
	use namespace g2d;
	/**
	 * ...
	 * @author Pierre Chamberlain
	 */
	public class GTileMapAdvanced extends GRenderable {
		
		private var __iWidth:int;
		private var __iHeight:int;
		private var __iCols:int;
		private var __iRows:int;
		private var __aTiles:Vector.<int>;
		private var __aNewTileIndices:Vector.<int>
		private var __aTileset:Vector.<GTile>;
		
		private var __iTileWidth:int;
		private var __iTileHeight:int;
		private var __iTileWidthHalf:Number;
		private var __iTileHeightHalf:Number;
		
		public var pivotX:Number = 0;
		public var pivotY:Number = 0;
		
		public var tilesDrawn:int = 0;
		public var debugMargin:int = 0;
		
		private var _tempCol:int = 0;
		private var _tempRow:int = 0;
		private var _tempPoint:Point;
		
		public function GTileMapAdvanced(p_node:GNode) {
			super(p_node);
			
			_tempPoint = new Point();
			__aNewTileIndices = new Vector.<int>();
		}
		
		public override function dispose():void {
			if (!__aTiles) {
				return;
			}
			
			__aTiles.length = 0;
			__aTiles = null;
			
			while (__aTileset.length > 0) {
				var tile:Object = __aTileset.pop();
				if ("destroy" in tile) {
					Object(tile).destroy();
				}
				if ("dispose" in tile) {
					Object(tile).dispose();
				}
			}
			__aTileset.length = 0;
			__aTileset = null;
			
			__aNewTileIndices.length = 0;
			__aNewTileIndices = null;
			
			super.dispose();
		}
		
		public function setTileSet(pTileset:Vector.<GTile>):void {
			__aTileset = pTileset;
		}
		
		public function setTiles(pTiles:Vector.<int>, pMapCols:int, pMapRows:int, pTileWidth:int, pTileHeight:int):void {
			if (pTiles == null || pMapCols * pMapRows != pTiles.length) throw new Error("Cols x Rows don't match the length of Tiles supplied! - " + [pMapCols,pMapRows,pTiles.length].join(" : "));
			
			__aTiles = pTiles;
			__iCols = pMapCols;
			__iRows = pMapRows;
			
			setTileSize( pTileWidth, pTileHeight );
		}
		
		public function setTileSize( pTileWidth:int, pTileHeight:int ):void {
			__iTileWidth =	pTileWidth;
			__iTileHeight =	pTileHeight;
			
			__iWidth = __iCols * __iTileWidth;
			__iHeight = __iRows * __iTileHeight;
			
			__iTileWidthHalf = __iTileWidth * .5;
			__iTileHeightHalf = __iTileHeight * .5;
		}
		
		public function pivotCentered():void {
			pivotX = -__iWidth * .5;
			pivotY = -__iHeight * .5;
		}
		
		public function setTileAtIndex( pTileIndex:int, pTile:int ):void {
			if (pTileIndex<0 || pTileIndex>=__aTiles.length) return;
			
			__aTiles[pTileIndex] = pTile;
		}
		
		public function getTileAtColRow( pTileCol:int, pTileRow:int ):GTile {
			if (pTileCol < 0 || pTileCol >= __iCols || pTileRow < 0 || pTileRow >= __iRows) return null;
			return inline_getTileAtColRow( pTileCol, pTileRow );
		}
		
		public function getTileAtXAndY( pX:Number, pY:Number ):GTile {
			var col:int = pX / (__iTileWidth * node.transform.nWorldScaleX);
			var row:int = pY / (__iTileHeight * node.transform.nWorldScaleY);
			
			return inline_getTileAtColRow(col, row);
		}
		
		public function getTileAtIndex( pTileIndex:int ):GTile {
			if (pTileIndex < 0 || pTileIndex >= __aTiles.length) {
				return null;
			}
			
			//In case the tiles have been modified before accessing them (externally), reapply them:
			inline_applyNewTileIndices();
			
			var tileID:int =	__aTiles[pTileIndex];
			if (tileID < 0 || tileID >= __aTileset.length) {
				return null;
			}
			return __aTileset[ tileID ];
		}
		
		public function setTileAtPosition( pX:Number, pY:Number, pNewTileID:int ):int {
			var trans:GTransform =		node.transform;
			
			inline_getColRowAtPosition( pX, pY, trans.nWorldX, trans.nWorldY, trans.nWorldScaleX, trans.nWorldScaleY, trans.nWorldRotation );
			
			var oldIndex:int= inline_setTileIndexAtColRow( _tempCol, _tempRow, pNewTileID);
			
			return oldIndex;
		}
		
		public function getColRowAtPosition( pX:Number, pY:Number ):Point {
			var trans:GTransform =		node.transform;
			
			inline_getColRowAtPosition( pX, pY, trans.nWorldX, trans.nWorldY, trans.nWorldScaleX, trans.nWorldScaleY, trans.nWorldRotation );
			_tempPoint.setTo( _tempCol, _tempRow );
			
			return _tempPoint;
		}
		
		[Inline]
		private final function inline_getColRowAtPosition(pX:Number, pY:Number, worldX:Number, worldY:Number, worldScaleX:Number, worldScaleY:Number, worldRotation:Number):void {
			var theX:Number =	(pX - worldX);
			var theY:Number =	(pY - worldY);
			
			var atan:Number =	Math.atan2( theY, theX ) - worldRotation;
			var hypo:Number =	Math.sqrt( theX * theX + theY * theY);
			theX =	Math.cos(atan) * hypo;
			theY =	Math.sin(atan) * hypo;
			
			_tempCol =	(theX - pivotX * worldScaleX) / worldScaleX / __iTileWidth;
			_tempRow = 	(theY - pivotY * worldScaleY) / worldScaleY / __iTileHeight;
		}
		
		[Inline]
		private final function inline_getTileAtColRow(pTileCol:int, pTileRow:int):GTile {
			var tileID:int =	__aTiles[pTileCol + pTileRow * __iCols];
			if (tileID < 0 || tileID >= __aTileset.length) {
				return null;
			}
			return __aTileset[ tileID ];
		}
		
		[Inline]
		private final function inline_setTileIndexAtColRow(pTileCol:int, pTileRow:int, pNewTileID:int):int {
			if (pTileCol<0 || pTileCol>=__iCols || pTileRow<0 || pTileRow>=__iRows)
				return -1;
			
			var index:int = pTileCol + pTileRow * __iCols;
			var old:int = __aTiles[index];
			__aNewTileIndices[__aNewTileIndices.length] = index;
			__aNewTileIndices[__aNewTileIndices.length] = pNewTileID;
			//__aTiles[index] = pNewTileID;
			return old;
		}
		
		[Inline]
		private final function inline_applyNewTileIndices():void {
			while (__aNewTileIndices.length > 0) {
				var tileValue:int = __aNewTileIndices[__aNewTileIndices.length - 1];
				var index:int = __aNewTileIndices[__aNewTileIndices.length - 2];
				
				__aTiles[index] = tileValue;
				
				__aNewTileIndices.length -= 2;
			}
		}
		
		public override function render(p_context:GContext, p_camera:GCamera, p_maskRect:Rectangle):void {
			if (!__aTiles || __aTiles.length == 0) return;
			
			tilesDrawn = 0;
			
			//If there's been any tileset changes, apply them now!
			inline_applyNewTileIndices();
			
			var radian:Number =	180 / Math.PI,
				hypo:Number, atan:Number, angledX:Number, angledY:Number,
				transform:GTransform =	node.transform,
				tileWidth:Number =		__iTileWidth * transform.nWorldScaleX,
				tileHeight:Number =		__iTileHeight * transform.nWorldScaleY,
				viewWidth:Number =		p_camera.rViewRectangle.width,
				viewHeight:Number =		p_camera.rViewRectangle.height,
				worldScaleX:Number =	transform.nWorldScaleX,
				worldScaleY:Number =	transform.nWorldScaleY,
				worldRotation:Number =	transform.nWorldRotation,
				worldRed:Number =		transform.nWorldRed,
				worldGreen:Number =		transform.nWorldGreen,
				worldBlue:Number =		transform.nWorldBlue,
				worldAlpha:Number =		transform.nWorldAlpha,
				worldX:Number =			transform.nWorldX,
				worldY:Number =			transform.nWorldY,
				x:Number, y:Number,
				c:int, cLen:int, r:int, rLen:int,
				tile:GTile, tileTexture:GTexture;
			
			for (r = 0, rLen = __iRows; r < rLen; r++) {
				y =	(r * __iTileHeight + pivotY + __iTileHeightHalf) * worldScaleY;
				
				for (c = 0, cLen = __iCols; c < cLen; c++) {
					tile =			inline_getTileAtColRow(c, r);
					if (!tile) {
						continue;
					}
					
					tileTexture =	GTexture.getTextureById( tile.textureId );
					
					x =	(c * __iTileWidth + pivotX + __iTileWidthHalf) * worldScaleX;
					
					hypo =	Math.sqrt(x * x + y * y);
					atan =	Math.atan2(y, x) + worldRotation;
					
					angledX =	worldX + Math.cos(atan) * hypo;
					angledY =	worldY + Math.sin(atan) * hypo;
					
					//Culler:
					if (angledX + tileWidth< debugMargin || angledX-tileWidth+debugMargin>viewWidth ||
						angledY + tileHeight < debugMargin || angledY - tileHeight+debugMargin > viewHeight) {
						continue;
					}
					
					tilesDrawn++;
					
					p_context.draw( tileTexture,
						angledX, angledY,
						worldScaleX, worldScaleY,
						worldRotation, 
						worldRed, worldGreen, worldBlue, worldAlpha,
						1, p_maskRect );
				}
			}
		}
		
		public function get mapCols():int {  return __iCols; }
		public function get mapRows():int {  return __iRows; }
		public function get mapWidth():int { return __iWidth; }
		public function get mapHeight():int { return __iHeight; }
		public function get tileWidth():int { return __iTileWidth; }
		public function get tileHeight():int { return __iTileHeight; }
	}
}